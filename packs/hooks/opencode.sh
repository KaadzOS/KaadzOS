#!/bin/sh
set -eu

die() {
  printf 'opencode hook: %s\n' "$1" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

case ${1:-add} in
  add)
    for tool in curl sha256sum tar dpkg install; do
      have "$tool" || die "$tool is required to install the opencode pack"
    done

    arch=$(dpkg --print-architecture) || die "could not detect the architecture"
    case $arch in
      amd64)
        asset=opencode-linux-x64.tar.gz
        expected=563b5d663637226b6e3bb4bb6803281bc39b0d2cd88db06d674b6420aab009b0
        ;;
      arm64)
        asset=opencode-linux-arm64.tar.gz
        expected=9d10185acdb72336e086e699ca363a6065f410fd3c1caed0dc8046e95ac06ccb
        ;;
      *)
        die "unsupported architecture '$arch' (opencode provides amd64 and arm64)"
        ;;
    esac
    [ -n "${expected:-}" ] || die "no SHA-256 is pinned for $asset"

    tmp=$(mktemp -d) || die "could not create a temporary directory"
    trap 'rm -rf "$tmp"' 0 1 2 15
    archive="$tmp/$asset"

    curl -fsSL --connect-timeout 20 --max-time 900 \
      "https://github.com/anomalyco/opencode/releases/download/v2.3.2/$asset" \
      -o "$archive" || die "download failed for $asset"

    printf '%s  %s\n' "$expected" "$archive" > "$tmp/SHA256"
    sha256sum -c "$tmp/SHA256" >/dev/null 2>&1 \
      || die "SHA-256 verification failed for $asset"

    mkdir "$tmp/unpack" || die "could not create the unpack directory"
    tar -xzf "$archive" -C "$tmp/unpack" || die "could not unpack $asset"
    [ -f "$tmp/unpack/opencode" ] || die "$asset does not contain the opencode binary"

    install -m 0755 "$tmp/unpack/opencode" /usr/local/bin/opencode \
      || die "could not install /usr/local/bin/opencode"

    hook_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) \
      || die "could not find the hook directory"
    [ -f "$hook_dir/opencode.desktop" ] || die "missing opencode.desktop next to the hook"
    install -m 0644 "$hook_dir/opencode.desktop" /usr/share/applications/opencode.desktop \
      || die "could not install the opencode desktop entry"

    printf 'kaadzos: opencode v2.3.2 installed\n'
    ;;
  remove)
    rm -f /usr/local/bin/opencode /usr/share/applications/opencode.desktop
    ;;
  *)
    die "unknown action '${1:-}' (expected add or remove)"
    ;;
esac
