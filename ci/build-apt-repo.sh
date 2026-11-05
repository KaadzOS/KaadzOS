#!/usr/bin/env bash
# Build a signed APT repository from a directory of .deb files.
#
# Usage:
#   ci/build-apt-repo.sh <packages-dir> <repo-dir> [suite] [component] [arch]
#
# Environment:
#   GPG_KEY_ID        signing key (required unless ALLOW_UNSIGNED=1)
#   GPG_PASSPHRASE    passphrase for the signing key (optional)
#   APT_BASE_URL      public URL of the repository root; when set, a
#                     kaadzos.sources file is written next to the pool
#   ALLOW_UNSIGNED=1  build an unsigned repository (tests only)
#
# Layout produced:
#   <repo-dir>/dists/<suite>/InRelease
#   <repo-dir>/dists/<suite>/Release
#   <repo-dir>/dists/<suite>/Release.gpg
#   <repo-dir>/dists/<suite>/<component>/binary-<arch>/Packages{,.gz,.xz}
#   <repo-dir>/pool/<component>/<letter>/<package>/<deb>
#   <repo-dir>/kaadzos-archive-keyring.asc
#   <repo-dir>/kaadzos-archive-keyring.gpg
#   <repo-dir>/kaadzos.sources            (when APT_BASE_URL is set)
set -euo pipefail

packages_dir=${1:?usage: build-apt-repo.sh <packages-dir> <repo-dir> [suite] [component] [arch]}
repo_dir=${2:?usage: build-apt-repo.sh <packages-dir> <repo-dir> [suite] [component] [arch]}
suite=${3:-trixie}
component=${4:-main}
arch=${5:-amd64}

packages_dir=$(cd "$packages_dir" && pwd)

rm -rf "$repo_dir"
mkdir -p "$repo_dir/pool/$component"
mkdir -p "$repo_dir/dists/$suite/$component/binary-$arch"

shopt -s nullglob
debs=("$packages_dir"/*.deb)
if [ ${#debs[@]} -eq 0 ]; then
  echo "error: no .deb files in $packages_dir" >&2
  exit 1
fi

# Put each package in the conventional pool path. dpkg-scanpackages emits
# Filename paths relative to the repository root, so the pool must live there.
for deb in "${debs[@]}"; do
  package=$(dpkg-deb -f "$deb" Package)
  deb_arch=$(dpkg-deb -f "$deb" Architecture)
  if [ -z "$package" ]; then
    echo "error: $deb has no Package field" >&2
    exit 1
  fi
  if [ "$deb_arch" != "$arch" ] && [ "$deb_arch" != "all" ]; then
    echo "error: $deb is $deb_arch, expected $arch or all" >&2
    exit 1
  fi
  letter=${package:0:1}
  dest="$repo_dir/pool/$component/$letter/$package"
  mkdir -p "$dest"
  cp "$deb" "$dest/"
done

# Packages index, plus the compressed variants apt prefers.
(
  cd "$repo_dir"
  dpkg-scanpackages --multiversion "pool/$component" /dev/null \
    > "dists/$suite/$component/binary-$arch/Packages"
)

packages_file="$repo_dir/dists/$suite/$component/binary-$arch/Packages"
gzip -9 -n -c "$packages_file" > "$packages_file.gz"
if command -v xz >/dev/null 2>&1; then
  xz -9 -c "$packages_file" > "$packages_file.xz"
fi

# Release metadata. apt-ftparchive writes checksums for every file under
# dists/<suite>, including the compressed Packages files. Write the result
# outside that tree first: if the output file exists inside it, apt-ftparchive
# records a zero-length entry for Release itself.
release_tmp="$repo_dir/dists/$suite.Release.tmp"
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=KaadzOS" \
  -o "APT::FTPArchive::Release::Label=KaadzOS" \
  -o "APT::FTPArchive::Release::Suite=$suite" \
  -o "APT::FTPArchive::Release::Codename=$suite" \
  -o "APT::FTPArchive::Release::Architectures=$arch" \
  -o "APT::FTPArchive::Release::Components=$component" \
  -o "APT::FTPArchive::Release::Description=KaadzOS optional package archive" \
  release "$repo_dir/dists/$suite" > "$release_tmp"
mv "$release_tmp" "$repo_dir/dists/$suite/Release"

# Sign Release twice: InRelease is the clear-signed file apt reads first,
# Release.gpg is the detached signature older clients fall back to.
if [ -n "${GPG_KEY_ID:-}" ]; then
  gpg_args=(--batch --yes --armor --local-user "$GPG_KEY_ID")
  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    gpg_args+=(--pinentry-mode loopback --passphrase "$GPG_PASSPHRASE")
  fi
  gpg "${gpg_args[@]}" --detach-sign \
    --output "$repo_dir/dists/$suite/Release.gpg" \
    "$repo_dir/dists/$suite/Release"
  gpg "${gpg_args[@]}" --clearsign \
    --output "$repo_dir/dists/$suite/InRelease" \
    "$repo_dir/dists/$suite/Release"

  gpg --batch --yes --armor --export "$GPG_KEY_ID" \
    > "$repo_dir/kaadzos-archive-keyring.asc"
  gpg --batch --yes --dearmor \
    < "$repo_dir/kaadzos-archive-keyring.asc" \
    > "$repo_dir/kaadzos-archive-keyring.gpg"
elif [ "${ALLOW_UNSIGNED:-0}" = 1 ]; then
  echo "warning: building an unsigned repository (ALLOW_UNSIGNED=1)" >&2
else
  echo "error: GPG_KEY_ID is not set (or set ALLOW_UNSIGNED=1 for tests)" >&2
  exit 1
fi

# A ready-to-copy deb822 source stanza for installed systems.
if [ -n "${APT_BASE_URL:-}" ]; then
  cat > "$repo_dir/kaadzos.sources" <<EOF
Types: deb
URIs: ${APT_BASE_URL%/}
Suites: $suite
Components: $component
Signed-By: /usr/share/keyrings/kaadzos-archive-keyring.gpg
EOF
fi

echo "repository built: $repo_dir"
find "$repo_dir" -type f -printf '%P\n' | sort
