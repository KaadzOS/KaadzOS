#!/bin/sh
# Post-install hook for the windows pack: enable i386 multiarch for Wine32 and
# install Bottles (not packaged in Debian) from Flathub.
set -eu

action=${1:-add}

case $action in
  add)
    dpkg --add-architecture i386
    env DEBIAN_FRONTEND=noninteractive apt-get -y update
    env DEBIAN_FRONTEND=noninteractive apt-get -y install wine32 || \
      echo "kaadzos: could not install wine32; 32-bit Windows apps may not run" >&2

    if command -v flatpak >/dev/null 2>&1; then
      flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
      flatpak install -y flathub com.usebottles.bottles || \
        echo "kaadzos: Bottles install failed; install it later with: flatpak install flathub com.usebottles.bottles" >&2
    fi
    ;;
  remove)
    if command -v flatpak >/dev/null 2>&1; then
      flatpak uninstall -y com.usebottles.bottles >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "windows hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
