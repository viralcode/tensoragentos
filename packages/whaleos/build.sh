#!/bin/bash
# ════════════════════════════════════════════════
# Build WhaleOS — TensorAgent OS Native Desktop Shell
# ════════════════════════════════════════════════
set -e
cd /opt/ainux/whaleos

echo "Building WhaleOS..."

# ── Run Qt6 MOC on SystemManager (Q_OBJECT requires it) ──
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) systemmanager.h -o moc_systemmanager.cpp

# ── Run MOC on main.cpp (ClipboardFilter has Q_OBJECT) ──
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) main.cpp -o main.moc

# ── Compile with Wayland Compositor + PAM support ──
# -lpam: PAM authentication (replaces insecure /etc/shadow direct reading)
g++ -o whaleos main.cpp moc_systemmanager.cpp \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui Qt6WaylandCompositor) \
    -lpam -fPIC

echo "WhaleOS built successfully"
