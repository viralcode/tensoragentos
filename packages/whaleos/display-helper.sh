#!/bin/bash
# display-helper.sh — Display settings helper for TensorAgent OS
# Used by WhaleOS QML shell to query and set display configuration
# Supports: wlr-randr (Wayland/wlroots), xrandr (X11 fallback), fbset (framebuffer)

set -e

get_gpu_info() {
    local gpu_name="Unknown"
    local driver="Unknown"
    local renderer="software"

    # Try lspci first
    if command -v lspci &>/dev/null; then
        gpu_name=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //' || echo "Unknown")
    fi

    # Try DRM
    if [ -d /sys/class/drm/card0 ]; then
        local drm_driver=$(readlink -f /sys/class/drm/card0/device/driver 2>/dev/null | xargs basename 2>/dev/null || echo "")
        [ -n "$drm_driver" ] && driver="$drm_driver"
    fi

    # Check renderer
    if [ -n "$WLR_RENDERER" ]; then
        renderer="$WLR_RENDERER"
    elif [ -f /proc/modules ]; then
        grep -q "virtio_gpu" /proc/modules 2>/dev/null && renderer="virtio-gpu"
    fi

    # If gpu_name is still generic, try to be more specific
    if [ "$gpu_name" = "Unknown" ] && [ "$driver" != "Unknown" ]; then
        case "$driver" in
            virtio*) gpu_name="VirtIO GPU" ;;
            i915) gpu_name="Intel Integrated Graphics" ;;
            amdgpu) gpu_name="AMD Radeon" ;;
            nouveau|nvidia) gpu_name="NVIDIA GPU" ;;
            *) gpu_name="$driver" ;;
        esac
    fi

    echo "{\"name\":\"$gpu_name\",\"driver\":\"$driver\",\"renderer\":\"$renderer\"}"
}

get_kernel_graphics() {
    local modules=""
    local compositor=""

    # List loaded graphics kernel modules
    if [ -f /proc/modules ]; then
        modules=$(awk '{print $1}' /proc/modules | grep -iE 'drm|gpu|video|fb|i915|amdgpu|nouveau|virtio' | tr '\n' ',' | sed 's/,$//')
    fi

    # Detect compositor
    if pgrep -x cage &>/dev/null; then
        compositor="Cage (wlroots)"
    elif pgrep -x sway &>/dev/null; then
        compositor="Sway"
    elif pgrep -x Hyprland &>/dev/null; then
        compositor="Hyprland"
    elif [ -n "$WAYLAND_DISPLAY" ]; then
        compositor="Wayland ($WAYLAND_DISPLAY)"
    elif [ -n "$DISPLAY" ]; then
        compositor="X11"
    else
        compositor="Unknown"
    fi

    echo "{\"modules\":\"$modules\",\"compositor\":\"$compositor\"}"
}

list_displays() {
    local current_w=0
    local current_h=0
    local current_refresh=60.0
    local modes="[]"

    # Try wlr-randr first (Wayland/wlroots)
    if command -v wlr-randr &>/dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
        local wlr_output=$(wlr-randr 2>/dev/null)
        if [ -n "$wlr_output" ]; then
            # Parse current resolution
            local current_line=$(echo "$wlr_output" | grep 'current' | head -1)
            if [ -n "$current_line" ]; then
                current_w=$(echo "$current_line" | grep -oP '(\d+)x\d+' | head -1 | cut -dx -f1)
                current_h=$(echo "$current_line" | grep -oP '\d+x(\d+)' | head -1 | cut -dx -f2)
                current_refresh=$(echo "$current_line" | grep -oP '[\d.]+(?= Hz)' | head -1)
            fi

            # Parse available modes
            modes=$(echo "$wlr_output" | grep -P '^\s+\d+x\d+' | while read -r line; do
                local w=$(echo "$line" | grep -oP '(\d+)x\d+' | head -1 | cut -dx -f1)
                local h=$(echo "$line" | grep -oP '\d+x(\d+)' | head -1 | cut -dx -f2)
                local r=$(echo "$line" | grep -oP '[\d.]+(?= Hz)' | head -1)
                local pref=""
                echo "$line" | grep -q 'preferred' && pref=",\"preferred\":true"
                local cur=""
                echo "$line" | grep -q 'current' && cur=",\"current\":true"
                echo "{\"width\":$w,\"height\":$h,\"refresh\":${r:-60.0}${pref}${cur}}"
            done | paste -sd, - | sed 's/^/[/' | sed 's/$/]/')
        fi

    # xrandr fallback
    elif command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        local xr_output=$(xrandr 2>/dev/null)
        if [ -n "$xr_output" ]; then
            local current_line=$(echo "$xr_output" | grep '\*' | head -1)
            if [ -n "$current_line" ]; then
                current_w=$(echo "$current_line" | awk '{print $1}' | cut -dx -f1)
                current_h=$(echo "$current_line" | awk '{print $1}' | cut -dx -f2)
                current_refresh=$(echo "$current_line" | grep -oP '[\d.]+(?=\*)' | head -1)
            fi

            modes=$(echo "$xr_output" | grep -P '^\s+\d+x\d+' | while read -r line; do
                local w=$(echo "$line" | awk '{print $1}' | cut -dx -f1)
                local h=$(echo "$line" | awk '{print $1}' | cut -dx -f2)
                local r=$(echo "$line" | grep -oP '[\d.]+' | tail -1)
                local cur=""
                echo "$line" | grep -q '\*' && cur=",\"current\":true"
                echo "{\"width\":$w,\"height\":$h,\"refresh\":${r:-60.0}${cur}}"
            done | paste -sd, - | sed 's/^/[/' | sed 's/$/]/')
        fi
    fi

    # Fallback: provide common resolutions if nothing detected
    if [ "$modes" = "[]" ] || [ -z "$modes" ]; then
        # Get current from framebuffer
        if [ -f /sys/class/graphics/fb0/virtual_size ]; then
            IFS=',' read current_w current_h < /sys/class/graphics/fb0/virtual_size
        fi
        [ "$current_w" -eq 0 ] 2>/dev/null && current_w=1920
        [ "$current_h" -eq 0 ] 2>/dev/null && current_h=1080
        current_refresh=60.0

        modes='[
            {"width":3840,"height":2160,"refresh":60.0},
            {"width":2560,"height":1440,"refresh":60.0},
            {"width":1920,"height":1200,"refresh":60.0},
            {"width":1920,"height":1080,"refresh":60.0,"preferred":true},
            {"width":1680,"height":1050,"refresh":60.0},
            {"width":1600,"height":900,"refresh":60.0},
            {"width":1440,"height":900,"refresh":60.0},
            {"width":1366,"height":768,"refresh":60.0},
            {"width":1280,"height":1024,"refresh":60.0},
            {"width":1280,"height":720,"refresh":60.0},
            {"width":1024,"height":768,"refresh":60.0},
            {"width":800,"height":600,"refresh":60.0}
        ]'
    fi

    local gpu=$(get_gpu_info)
    local gfx=$(get_kernel_graphics)

    cat <<ENDJSON
{
    "current": {"width":${current_w:-1920},"height":${current_h:-1080},"refresh":${current_refresh:-60.0}},
    "modes": $modes,
    "gpu": $gpu,
    "graphics": $gfx
}
ENDJSON
}

set_resolution() {
    local res="$1"
    local w=$(echo "$res" | cut -dx -f1)
    local h=$(echo "$res" | cut -dx -f2)

    if command -v wlr-randr &>/dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
        local output=$(wlr-randr 2>/dev/null | head -1 | awk '{print $1}')
        if [ -n "$output" ]; then
            wlr-randr --output "$output" --mode "${w}x${h}" 2>&1
            echo "{\"success\":true,\"resolution\":\"${w}x${h}\"}"
        else
            echo "{\"success\":false,\"error\":\"No output found\"}"
        fi
    elif command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        local output=$(xrandr | grep ' connected' | head -1 | awk '{print $1}')
        if [ -n "$output" ]; then
            xrandr --output "$output" --mode "${w}x${h}" 2>&1
            echo "{\"success\":true,\"resolution\":\"${w}x${h}\"}"
        else
            echo "{\"success\":false,\"error\":\"No output found\"}"
        fi
    else
        echo "{\"success\":false,\"error\":\"No display tool available (install wlr-randr)\"}"
    fi
}

case "${1:-list}" in
    list)   list_displays ;;
    set)    set_resolution "$2" ;;
    gpu)    get_gpu_info ;;
    gfx)    get_kernel_graphics ;;
    *)      echo "{\"error\":\"Unknown command: $1. Use: list, set, gpu, gfx\"}" ;;
esac
