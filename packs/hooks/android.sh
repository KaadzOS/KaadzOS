#!/bin/sh
# Post-install hook for the android pack (Waydroid).
set -eu

action=${1:-add}

case $action in
  add)
    if command -v waydroid >/dev/null 2>&1; then
      # First run downloads the Android system image (network required).
      if [ ! -f /var/lib/waydroid/waydroid.cfg ]; then
        if ! waydroid init; then
          echo "kaadzos: waydroid init failed (no network?); run 'waydroid init' later" >&2
        fi
      fi
    fi
    if [ ! -e /dev/binder ] && [ ! -e /dev/binderfs ]; then
      echo "kaadzos: note: binder not detected; load the binder kernel module if Waydroid fails to start" >&2
    fi
    ;;
  remove)
    if command -v waydroid >/dev/null 2>&1; then
      waydroid container stop >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "android hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
