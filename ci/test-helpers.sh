#!/bin/sh
# Umbrella validation for the POSIX-sh helpers. Syntax and shellcheck cover
# every helper; the functional suites below use local fakes for every external
# command so no host session, apt repository or upstream download is touched.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helpers="$root/config/includes.chroot/usr/local/bin"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

if ! command -v shellcheck >/dev/null 2>&1; then
  fail "shellcheck is required to validate the helpers"
fi

for helper in "$helpers"/kaadzos*; do
  [ -f "$helper" ] || continue
  dash -n "$helper" || fail "$(basename "$helper") does not parse as POSIX sh"
done

if ! shellcheck -s sh -e SC2024 "$helpers"/kaadzos*; then
  fail "shellcheck reported problems in the helper scripts"
fi

for suite in test-search test-file-actions test-control test-settings \
             test-packages test-opencode; do
  echo "running ci/$suite.sh"
  sh "$root/ci/$suite.sh" >/dev/null || fail "ci/$suite.sh failed"
done

[ "$failed" -eq 0 ] || exit 1
echo "helper scripts are valid"
