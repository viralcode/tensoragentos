#!/bin/bash
# Build WhaleOS native desktop shell
set -e
cd /opt/ainux/whaleos

# Run Qt6 MOC on SystemManager (Q_OBJECT requires it)
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) systemmanager.h -o moc_systemmanager.cpp

# Run MOC on main.cpp (ClipboardFilter has Q_OBJECT)
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) main.cpp -o main.moc

# Compile with MOC output + Wayland Compositor support
# -lcrypt needed for crypt(3) used in authenticate() to hash-check /etc/shadow
g++ -o whaleos main.cpp moc_systemmanager.cpp \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui Qt6WaylandCompositor) \
    -lcrypt -fPIC
echo "WhaleOS built successfully"

# Ensure ainux user can read /etc/shadow (needed for in-process auth without sudo)
usermod -aG shadow ainux 2>/dev/null || true
