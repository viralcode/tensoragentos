#!/bin/bash
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1000
# Start autocutsel to persist X11 clipboard when apps close
autocutsel -s CLIPBOARD -fork 2>/dev/null
autocutsel -fork 2>/dev/null

# Start VMware user tools agent if available for host-guest sync
if command -v vmware-user-suid-wrapper &>/dev/null; then
    vmware-user-suid-wrapper &
elif command -v vmware-user &>/dev/null; then
    vmware-user &
fi

LAST_X11=""
LAST_WL=""
echo "clipboard-sync.sh started"
while true; do
    X11_CLIP=$(timeout 0.2 xclip -selection clipboard -o 2>/dev/null) || X11_CLIP=""
    WL_CLIP=$(timeout 0.2 wl-paste --no-newline 2>/dev/null) || WL_CLIP=""
    if [ -n "$X11_CLIP" ] && [ "$X11_CLIP" != "$LAST_X11" ] && [ "$X11_CLIP" != "$WL_CLIP" ]; then
        echo "Syncing X11 -> Wayland: '$X11_CLIP'"
        printf '%s' "$X11_CLIP" | wl-copy 2>&1
        LAST_X11="$X11_CLIP"; LAST_WL="$X11_CLIP"
    fi
    if [ -n "$WL_CLIP" ] && [ "$WL_CLIP" != "$LAST_WL" ] && [ "$WL_CLIP" != "$X11_CLIP" ]; then
        echo "Syncing Wayland -> X11: '$WL_CLIP'"
        printf '%s' "$WL_CLIP" | xclip -selection clipboard 2>&1
        LAST_WL="$WL_CLIP"; LAST_X11="$WL_CLIP"
    fi
    sleep 0.5
done
