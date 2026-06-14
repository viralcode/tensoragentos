#!/bin/bash
# patch-gui-service.sh - Patches the compositor service on the VM to ensure display auto-resolution runs before geometry checks.

TARGET_SERVICE="/etc/systemd/system/whaleos-gui.service"
if [ -f "$TARGET_SERVICE" ]; then
    if ! grep -q "xrandr --auto" "$TARGET_SERVICE"; then
        echo "Patching whaleos-gui.service to run xrandr --auto..."
        sed -i 's|xdotool getdisplaygeometry|DISPLAY=:0 xrandr --auto \&\& xdotool getdisplaygeometry|' "$TARGET_SERVICE"
        systemctl daemon-reload
    else
        echo "whaleos-gui.service is already patched."
    fi
else
    echo "ERROR: $TARGET_SERVICE not found."
fi
