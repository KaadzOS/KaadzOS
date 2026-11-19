#!/bin/sh
# Post-install hook for the hardware pack. Firmware updates stay manual, but
# the fwupd refresh timer keeps metadata current without touching hardware.
set -eu

action=${1:-add}

case $action in
  add)
    if command -v systemctl >/dev/null 2>&1 &&
       systemctl cat fwupd-refresh.timer >/dev/null 2>&1; then
      if ! systemctl enable --now fwupd-refresh.timer >/dev/null 2>&1; then
        echo "kaadzos: could not enable fwupd-refresh.timer" >&2
      fi
    fi
    if command -v fwupdmgr >/dev/null 2>&1; then
      echo "kaadzos: firmware updates are manual; use GNOME Firmware or fwupdmgr" >&2
    fi
    ;;
  remove)
    if command -v systemctl >/dev/null 2>&1; then
      systemctl disable --now fwupd-refresh.timer >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "hardware hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
