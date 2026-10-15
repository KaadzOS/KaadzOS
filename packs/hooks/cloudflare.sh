#!/bin/sh
# Post-install hook for the cloudflare pack: install the cloudflared binary.
set -eu

action=${1:-add}
bin=/usr/local/bin/cloudflared

case $action in
  add)
    if ! command -v curl >/dev/null 2>&1; then
      echo "cloudflare hook: curl is required to download cloudflared" >&2
      exit 1
    fi
    arch=$(dpkg --print-architecture)
    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
    curl -fsSL "$url" -o "$bin"
    chmod 0755 "$bin"
    "$bin" --version >/dev/null 2>&1 || \
      echo "kaadzos: cloudflared downloaded but --version failed" >&2
    ;;
  remove)
    rm -f "$bin"
    ;;
  *)
    echo "cloudflare hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
