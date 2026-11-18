#!/bin/sh
# Verify every package named in a live-build package list resolves in the
# archive apt is configured to use. The build and pack-test jobs both call
# this, so the two checks cannot drift. Requires apt indexes to be current.
set -eu

list=${1:-config/package-lists/base.list.chroot}
if [ ! -r "$list" ]; then
  echo "cannot read package list: $list" >&2
  exit 1
fi

missing=0
while IFS= read -r package || [ -n "$package" ]; do
  case "$package" in
    ''|'#'*)
      continue
      ;;
  esac
  # Trim trailing whitespace so hand-edited lists stay usable.
  package=$(printf '%s' "$package" | sed 's/[[:space:]]*$//')
  [ -n "$package" ] || continue
  if ! apt-cache show "$package" >/dev/null 2>&1; then
    echo "unresolvable package in $list: $package" >&2
    missing=1
  fi
done < "$list"

if [ "$missing" -ne 0 ]; then
  echo "package list $list has unresolvable entries" >&2
  exit 1
fi
echo "all packages in $list resolve"
