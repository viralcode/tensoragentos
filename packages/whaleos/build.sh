#!/bin/bash
# Build WhaleOS native desktop shell
set -e
cd /opt/ainux/whaleos
g++ -o whaleos main.cpp \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui) \
    -fPIC
echo "WhaleOS built successfully"
