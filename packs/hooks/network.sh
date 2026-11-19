#!/bin/sh
# Post-install hook for the network pack: make a running NetworkManager pick up
# newly installed VPN and WireGuard plugins immediately.
set -eu

action=${1:-add}

case $action in
  add|remove)
    if command -v nmcli >/dev/null 2>&1; then
      nmcli general reload >/dev/null 2>&1 || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
      systemctl reload NetworkManager >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "network hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
