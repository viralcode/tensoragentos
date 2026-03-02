#!/bin/bash
# Build WhaleOS native desktop shell
set -e
cd /opt/ainux/whaleos

# Run Qt6 MOC on SystemManager (Q_OBJECT requires it)
/usr/lib/qt6/libexec/moc $(pkg-config --cflags Qt6Core) systemmanager.h -o moc_systemmanager.cpp

# Compile with MOC output
g++ -o whaleos main.cpp moc_systemmanager.cpp \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui) \
    -fPIC
echo "WhaleOS built successfully"
