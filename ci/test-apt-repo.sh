#!/usr/bin/env bash
# Prove the optional APT repository pipeline without any Cloudflare
# credentials: generate an ephemeral signing key, build a test package and a
# signed repository, then make apt consume it.
#
# Runs inside a debian:trixie container as root. The test package is installed
# into the container and discarded with it.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'gpgconf --kill all 2>/dev/null || true; rm -rf "$tmp"' EXIT
chmod 755 "$tmp"

export GNUPGHOME="$tmp/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

echo "== generate an ephemeral signing key =="
gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key "KaadzOS Repository Test <test@kaadzos.invalid>" \
  ed25519 sign 1d
key_id=$(gpg --batch --list-secret-keys --with-colons |
  awk -F: '/^sec:/ {print $5; exit}')
test -n "$key_id"
echo "key: $key_id"

echo "== build a test package =="
mkdir -p "$tmp/debs"
pkg="$tmp/pkg/kaadzos-hello"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/share/kaadzos"
cat > "$pkg/DEBIAN/control" <<'EOF'
Package: kaadzos-hello
Version: 0.0.1
Architecture: all
Maintainer: KaadzOS Test <test@kaadzos.invalid>
Section: misc
Priority: optional
Description: Test package for the KaadzOS APT repository
EOF
printf 'hello from the KaadzOS test archive\n' > "$pkg/usr/share/kaadzos/hello"
dpkg-deb --build --root-owner-group "$pkg" \
  "$tmp/debs/kaadzos-hello_0.0.1_all.deb"

echo "== build and sign the repository =="
GPG_KEY_ID="$key_id" \
APT_BASE_URL="https://example.invalid/apt" \
  bash "$root/ci/build-apt-repo.sh" "$tmp/debs" "$tmp/repo" trixie main amd64

test -f "$tmp/repo/dists/trixie/InRelease"
test -f "$tmp/repo/dists/trixie/Release.gpg"
test -f "$tmp/repo/kaadzos-archive-keyring.asc"
test -f "$tmp/repo/kaadzos-archive-keyring.gpg"
test -f "$tmp/repo/kaadzos.sources"
grep -q '^Package: kaadzos-hello$' \
  "$tmp/repo/dists/trixie/main/binary-amd64/Packages"
grep -q '^URIs: https://example.invalid/apt$' "$tmp/repo/kaadzos.sources"

echo "== verify the InRelease signature directly =="
gpgv --keyring "$tmp/repo/kaadzos-archive-keyring.gpg" \
  "$tmp/repo/dists/trixie/InRelease"

echo "== apt consumes the repository =="
# apt's _apt sandbox user cannot read a mode-700 mktemp directory; root is fine
# in this disposable container.
chmod -R a+rX "$tmp/repo"
keyring="$tmp/repo/kaadzos-archive-keyring.gpg"
cat > "$tmp/kaadzos.list" <<EOF
deb [signed-by=$keyring] file://$tmp/repo trixie main
EOF
apt_opts=(
  -o Dir::Etc::sourcelist="$tmp/kaadzos.list"
  -o Dir::Etc::sourceparts=-
  -o APT::Sandbox::User=root
  -o Acquire::Languages=none
)
apt-get update "${apt_opts[@]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  "${apt_opts[@]}" kaadzos-hello
test -f /usr/share/kaadzos/hello
grep -q 'hello from the KaadzOS test archive' /usr/share/kaadzos/hello

echo "== gpgv refuses a tampered Release file =="
cp -R "$tmp/repo" "$tmp/tampered"
printf '\n' >> "$tmp/tampered/dists/trixie/Release"
if gpgv --keyring "$tmp/tampered/kaadzos-archive-keyring.gpg" \
  "$tmp/tampered/dists/trixie/Release.gpg" \
  "$tmp/tampered/dists/trixie/Release" >/dev/null 2>&1; then
  echo "error: gpgv accepted a tampered Release file" >&2
  exit 1
fi
echo "tampered Release rejected as expected"

echo "== repository test passed =="
