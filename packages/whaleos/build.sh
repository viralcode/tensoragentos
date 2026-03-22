#!/bin/bash
# ════════════════════════════════════════════════
# Build WhaleOS — TensorAgent OS Native Desktop Shell
# ════════════════════════════════════════════════
set -e
cd /opt/ainux/whaleos

echo "Building WhaleOS..."

# ── Run Qt6 MOC on all Q_OBJECT headers ──
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) systemmanager.h -o moc_systemmanager.cpp
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) ptyprocess.h -o moc_ptyprocess.cpp
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) terminalemulator.h -o moc_terminalemulator.cpp

# ── Run MOC on main.cpp (ClipboardFilter has Q_OBJECT) ──
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) main.cpp -o main.moc

# ── Compile with Wayland Compositor + PAM + PTY support ──
# -lpam: PAM authentication
# -lutil: forkpty() for real pseudo-terminal support
g++ -o whaleos main.cpp moc_systemmanager.cpp moc_ptyprocess.cpp moc_terminalemulator.cpp \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui Qt6WaylandCompositor) \
    -lpam -lutil -fPIC

echo "WhaleOS built successfully"

# ── Build popup_fix.cpp LD_PRELOAD shim (optional) ──
# Fixes Qt 6.4.2's missing xdg_popup_destroy/xdg_popup_grab implementations
# Note: With Firefox ESR as default browser, this is no longer critical
# but still useful if users install Chromium from the Package Store.
if [ -f popup_fix.cpp ] && pkg-config --exists wayland-server 2>/dev/null; then
    echo "Building popup_fix.cpp LD_PRELOAD shim..."
    g++ -std=c++17 -shared -fPIC popup_fix.cpp -o libpopupfix.so \
        $(pkg-config --cflags --libs wayland-server) \
        -O2 -Wall
    DEST="/opt/ainux/whaleos/libpopupfix.so"
    [ "$(realpath libpopupfix.so)" != "$(realpath $DEST 2>/dev/null)" ] && cp libpopupfix.so "$DEST" || true
    echo "popup_fix shim built: $DEST"
else
    echo "WARNING: wayland-server not found, skipping popup_fix shim"
fi
