#!/bin/sh
# Build the Calamares locale-map LD_PRELOAD filter against trixie's Qt6.
# The build container installs g++, qt6-base-dev and pkg-config; the resulting
# .so is staged into the live image and loaded only by kaadzos-install.
set -eu

if ! pkg-config --exists Qt6Gui; then
  echo "Qt6Gui development files are missing; install qt6-base-dev." >&2
  exit 1
fi

install -d config/includes.chroot/usr/local/lib
g++ -shared -fPIC -O2 -std=c++17 \
  -o config/includes.chroot/usr/local/lib/kaadzos-calamares-map.so \
  ci/calamares-map-filter.cpp \
  $(pkg-config --cflags --libs Qt6Gui) -ldl

ls -l config/includes.chroot/usr/local/lib/kaadzos-calamares-map.so
