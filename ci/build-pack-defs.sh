#!/usr/bin/env bash
# Build the kaadzos-pack-defs .deb from the canonical packs/ tree.
#
# Usage:
#   ci/build-pack-defs.sh <version> <output-dir>
#
# The package installs to /usr/share/kaadzos/packs, which is the pack manager's
# default PACKS_DIR. Shipping the definitions through apt lets an installed
# system receive new packs without rebuilding the ISO.
set -euo pipefail

version=${1:?usage: build-pack-defs.sh <version> <output-dir>}
out=${2:?usage: build-pack-defs.sh <version> <output-dir>}

case "$version" in
  ''|*[!0-9A-Za-z.+:~-]*)
    echo "error: invalid Debian version: $version" >&2
    exit 1
    ;;
esac

root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"
out=$(cd "$out" && pwd)
pkg="$out/kaadzos-pack-defs"

rm -rf "$pkg"
mkdir -p "$pkg/DEBIAN" "$pkg/usr/share/kaadzos"
cp -R "$root/packs" "$pkg/usr/share/kaadzos/packs"

if [ -d "$pkg/usr/share/kaadzos/packs/hooks" ]; then
  find "$pkg/usr/share/kaadzos/packs/hooks" -type f -name '*.sh' \
    -exec chmod 0755 {} +
fi

installed_size=$(du -sk "$pkg/usr" | cut -f1)

cat > "$pkg/DEBIAN/control" <<EOF
Package: kaadzos-pack-defs
Version: $version
Architecture: all
Maintainer: KaadzOS <kaadzos@users.noreply.github.com>
Section: admin
Priority: optional
Installed-Size: $installed_size
Description: Declarative pack definitions for the KaadzOS pack manager
 The kaadzos CLI reads key=value pack definitions from
 /usr/share/kaadzos/packs. This package ships the canonical definitions and
 their hooks so an installed system can receive pack updates through apt
 without rebuilding the ISO.
EOF

# Fixed timestamps keep the .deb reproducible for a given input tree.
find "$pkg" -exec touch -h -d '2026-01-01 00:00:00 UTC' {} +

dpkg-deb --build --root-owner-group "$pkg" \
  "$out/kaadzos-pack-defs_${version}_all.deb"

echo "built $out/kaadzos-pack-defs_${version}_all.deb"
