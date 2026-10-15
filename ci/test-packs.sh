#!/usr/bin/env bash
# Pack-manager tests: verify declarative pack resolution, requirement gating,
# clear errors and idempotency. Runs inside a debian:trixie container as root,
# so no package installs are performed (dry-run only) except apt-cache lookups.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cli="$root/config/includes.chroot/usr/local/bin/kaadzos"
packs="$root/packs"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export KAADZOS_PACKS_DIR="$packs"
export KAADZOS_STATE_DIR="$tmp/state"

pass=0
fail=0

ok()  { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }

# run_ok <desc> <cmd...>   -> pass when the command exits 0
run_ok() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

# run_fail <desc> <cmd...> -> pass when the command exits non-zero
run_fail() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then bad "$desc (expected failure)"; else ok "$desc"; fi
}

echo "== syntax =="
# dash -n exits 0 when the script parses; a non-zero result means a bashism.
run_ok "CLI parses under dash" dash -n "$cli"
for h in "$packs"/hooks/*.sh; do
  [ -f "$h" ] || continue
  run_ok "hook parses under dash: $(basename "$h")" dash -n "$h"
done

echo "== pack parsing / resolution =="
run_ok "kaadzos list resolves every pack" sh "$cli" list
run_ok "kaadzos status runs" sh "$cli" status

# Every *.pack file must appear as a resolvable row in `list`. Capture the
# output once: piping the CLI live into `grep -q` under `pipefail` races a
# SIGPIPE when grep exits on an early match.
list_out=$(sh "$cli" list)
n_files=0
for f in "$packs"/*.pack; do
  [ -f "$f" ] || continue
  n_files=$((n_files + 1))
  name=$(sed -n 's/^name=//p' "$f")
  if printf '%s\n' "$list_out" | grep -q "^$name "; then
    ok "pack listed: $name"
  else
    bad "pack listed: $name"
  fi
done
echo "found $n_files pack files"

echo "== dry-run add resolves actions =="
# dev is Debian-native (no third-party repo): dry-run must plan an apt install.
out=$(KAADZOS_DRY_RUN=1 sh "$cli" add dev 2>&1 || true)
if printf '%s' "$out" | grep -q "apt-get -y install"; then
  ok "dev dry-run plans an apt install"
else
  bad "dev dry-run plans an apt install"
fi
if printf '%s' "$out" | grep -q "git"; then
  ok "dev dry-run includes git"
else
  bad "dev dry-run includes git"
fi

# android uses a third-party apt repo + signing key.
out=$(KAADZOS_DRY_RUN=1 WAYLAND_DISPLAY=wayland-0 sh "$cli" add android 2>&1 || true)
if printf '%s' "$out" | grep -q "add apt repo"; then
  ok "android dry-run plans the Waydroid repo"
else
  bad "android dry-run plans the Waydroid repo"
fi
if printf '%s' "$out" | grep -q "import signing key"; then
  ok "android dry-run plans a signing key import"
else
  bad "android dry-run plans a signing key import"
fi

echo "== requirement gating =="
run_fail "android refused without a Wayland session" \
  env -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE KAADZOS_DRY_RUN=1 sh "$cli" add android
run_ok "android accepted with WAYLAND_DISPLAY set" \
  env WAYLAND_DISPLAY=wayland-0 KAADZOS_DRY_RUN=1 sh "$cli" add android

echo "== clear errors =="
run_fail "unknown pack fails" env KAADZOS_DRY_RUN=1 sh "$cli" add nosuchpack
run_fail "add without an argument fails" sh "$cli" add
run_fail "unknown command fails" sh "$cli" frobnicate
err=$(KAADZOS_DRY_RUN=1 sh "$cli" add nosuchpack 2>&1 || true)
if printf '%s' "$err" | grep -qi "unknown pack"; then
  ok "unknown pack error message is clear"
else
  bad "unknown pack error message is clear"
fi

echo "== idempotency =="
# Dry-run must not mutate state.
rm -rf "$tmp/state"
KAADZOS_DRY_RUN=1 sh "$cli" add dev >/dev/null 2>&1 || true
if [ -s "$tmp/state/installed" ]; then
  bad "dry-run does not write the installed list"
else
  ok "dry-run does not write the installed list"
fi

# Seed an installed pack: re-adding must be a no-op that still succeeds.
mkdir -p "$tmp/state"
printf 'dev\n' > "$tmp/state/installed"
run_ok "add is idempotent when already installed" \
  env KAADZOS_DRY_RUN=1 sh "$cli" add dev
already=$(KAADZOS_DRY_RUN=1 sh "$cli" add dev 2>&1 || true)
if printf '%s\n' "$already" | grep -q "already installed"; then
  ok "re-add reports 'already installed'"
else
  bad "re-add reports 'already installed'"
fi

# Removing something not installed must be a clean no-op.
run_ok "remove is idempotent when not installed" \
  env KAADZOS_DRY_RUN=1 sh "$cli" remove cloudflare

# Removing an installed pack must plan the removal.
run_ok "remove plans actions for an installed pack" \
  env KAADZOS_DRY_RUN=1 sh "$cli" remove dev

echo "== Debian package availability (packs without a third-party repo) =="
for f in "$packs"/*.pack; do
  [ -f "$f" ] || continue
  if grep -q '^repo-url=' "$f"; then
    continue   # third-party repo packages are not in the Debian archive
  fi
  apt_line=$(sed -n 's/^apt=//p' "$f")
  [ -n "$apt_line" ] || continue
  for pkg in $apt_line; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      ok "available in trixie: $pkg"
    else
      bad "available in trixie: $pkg (from $(basename "$f"))"
    fi
  done
done

echo
echo "passed: $pass  failed: $fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
