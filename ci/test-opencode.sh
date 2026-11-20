#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cli="$root/config/includes.chroot/usr/local/bin/kaadzos"
packs="$root/packs"
pack="$packs/opencode.pack"
hook="$packs/hooks/opencode.sh"
desktop="$packs/hooks/opencode.desktop"
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-opencode"
settings="$root/config/includes.chroot/usr/local/bin/kaadzos-settings"
search="$root/config/includes.chroot/usr/local/bin/kaadzos-search"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
install_root="$tmp/install"
log="$tmp/commands.log"
mkdir -p "$bin" "$home" "$config" "$install_root"

export HOME="$home"
export XDG_CONFIG_HOME="$config"
export PATH="$bin:$PATH"
export KAADZOS_TEST_LOG="$log"
export FAKE_INSTALL_ROOT="$install_root"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

expect() {
  grep -Fq -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

expect_absent() {
  if grep -Fq -- "$1" "$log"; then
    fail "unexpected command: $1"
  fi
}

write_logger() {
  name=$1
  cat > "$bin/$name" <<EOF
#!/bin/sh
{
  printf '%s' '$name'
  for arg in "\$@"; do printf ' [%s]' "\$arg"; done
  printf '\\n'
} >> "\$KAADZOS_TEST_LOG"
EOF
  chmod +x "$bin/$name"
}

cat > "$bin/curl" <<'EOF'
#!/bin/sh
out=
prev=
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then out=$arg; fi
  prev=$arg
done
{
  printf 'curl'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
[ -n "$out" ] || exit 1
cp "$FAKE_OPENCODE_ARCHIVE" "$out"
EOF

cat > "$bin/sha256sum" <<'EOF'
#!/bin/sh
{
  printf 'sha256sum'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
if [ "${FAKE_SHA_FAIL:-0}" = 1 ]; then
  exit 1
fi
if [ "${1:-}" = "-c" ]; then
  line=$(cat "$2")
  case $line in
    "563b5d663637226b6e3bb4bb6803281bc39b0d2cd88db06d674b6420aab009b0  "*|"9d10185acdb72336e086e699ca363a6065f410fd3c1caed0dc8046e95ac06ccb  "*) exit 0 ;;
    *) exit 1 ;;
  esac
fi
exit 1
EOF

cat > "$bin/install" <<'EOF'
#!/bin/sh
{
  printf 'install'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
mode=
if [ "${1:-}" = "-m" ]; then
  mode=$2
  shift 2
fi
src=$1
dest=$2
target="$FAKE_INSTALL_ROOT/$(basename "$dest")"
cp "$src" "$target" && chmod "$mode" "$target"
EOF

cat > "$bin/dpkg" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_ARCH:-amd64}"
EOF

cat > "$bin/zenity" <<'EOF'
#!/bin/sh
{
  printf 'zenity'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
if [ "${FAKE_ZENITY_QUESTION_EXIT:-0}" != 0 ]; then
  exit 1
fi
exit 0
EOF

for command in opencode foot notify-send; do
  write_logger "$command"
done
chmod +x "$bin/curl" "$bin/sha256sum" "$bin/install" "$bin/dpkg" "$bin/zenity"

dash -n "$hook" || fail "the opencode hook does not parse under dash"
dash -n "$helper" || fail "kaadzos-opencode does not parse under dash"

grep -q '^name=opencode$' "$pack" || fail "pack name is wrong"
grep -q '^hook=opencode$' "$pack" || fail "pack hook is wrong"
grep -q '^requires=curl$' "$pack" || fail "pack does not require curl"
grep -q 'releases/download/v2.3.2' "$hook" || fail "the release is not pinned"
grep -q '563b5d663637226b6e3bb4bb6803281bc39b0d2cd88db06d674b6420aab009b0' "$hook" \
  || fail "the amd64 checksum is missing"
grep -q '9d10185acdb72336e086e699ca363a6065f410fd3c1caed0dc8046e95ac06ccb' "$hook" \
  || fail "the arm64 checksum is missing"
if grep -qE 'releases/latest|latest/download|\| *(sh|bash)' "$hook"; then
  fail "the hook uses a floating URL or a piped install script"
fi
if grep -qE 'eval|exec sudo|sudo -E|pkexec' "$hook" "$helper"; then
  fail "the pack contains an eval or privilege escalation"
fi
if grep -rniE 'API_KEY|SECRET_KEY|ACCESS_TOKEN|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20}|sk-[A-Za-z0-9]{20}|AKIA[0-9A-Z]{16}' \
    "$pack" "$hook" "$desktop" "$helper" >/dev/null 2>&1; then
  fail "a secret-shaped value is present in the pack files"
fi
if [ -e "$root/config/includes.chroot/usr/share/applications/opencode.desktop" ]; then
  fail "the desktop entry would be installed in the base image"
fi
grep -q '^Exec=kaadzos-opencode$' "$desktop" || fail "the desktop entry is miswired"
grep -q 'opencode.desktop' "$hook" || fail "the hook does not install the desktop entry"
grep -q 'OpenCode' "$settings" || fail "Settings has no OpenCode row"
grep -q 'OpenCode) opencode ;;' "$settings" || fail "Settings does not dispatch OpenCode"
grep -Fq 'Setting\tOpenCode\topencode' "$search" \
  || fail "Search has no OpenCode candidate"

out=$(KAADZOS_PACKS_DIR="$packs" KAADZOS_STATE_DIR="$tmp/state" \
  KAADZOS_DRY_RUN=1 sh "$cli" add opencode 2>&1 || true)
printf '%s' "$out" | grep -q 'hooks/opencode.sh add' \
  || fail "dry-run does not plan the hook"
[ ! -e "$install_root/opencode" ] || fail "dry-run installed the binary"

mkdir -p "$tmp/state"
printf 'opencode\n' > "$tmp/state/installed"
out=$(KAADZOS_PACKS_DIR="$packs" KAADZOS_STATE_DIR="$tmp/state" \
  KAADZOS_DRY_RUN=1 sh "$cli" remove opencode 2>&1 || true)
printf '%s' "$out" | grep -q 'hooks/opencode.sh remove' \
  || fail "dry-run does not plan hook removal"

mkdir "$tmp/fixture"
printf '#!/bin/sh\nprintf "fixture"\n' > "$tmp/fixture/opencode"
chmod +x "$tmp/fixture/opencode"
tar -czf "$tmp/fixture.tar.gz" -C "$tmp/fixture" opencode
export FAKE_OPENCODE_ARCHIVE="$tmp/fixture.tar.gz"

: > "$log"
sh "$hook" add >/dev/null 2>&1 || fail "the hook add path failed"
expect 'curl [-fsSL] [--connect-timeout] [20] [--max-time] [900]'
expect 'opencode-linux-x64.tar.gz'
expect 'sha256sum [-c]'
expect 'install [-m] [0755]'
expect '/usr/local/bin/opencode'
expect '/usr/share/applications/opencode.desktop'
[ -x "$install_root/opencode" ] || fail "the binary was not installed"
[ -f "$install_root/opencode.desktop" ] || fail "the desktop entry was not installed"
rm -f "$install_root/opencode" "$install_root/opencode.desktop"

: > "$log"
if FAKE_ARCH=i386 sh "$hook" add >/dev/null 2>&1; then
  fail "an unsupported architecture was accepted"
fi
expect_absent 'curl'

: > "$log"
sed '/^        expected=/d' "$hook" > "$tmp/no-checksum.sh"
if sh "$tmp/no-checksum.sh" add >/dev/null 2>&1; then
  fail "a hook without a checksum was accepted"
fi
expect_absent 'curl'

: > "$log"
if FAKE_SHA_FAIL=1 sh "$hook" add >/dev/null 2>&1; then
  fail "a failed checksum was accepted"
fi
expect_absent 'install'

mkdir "$tmp/removepin"
cat > "$tmp/removepin/rm" <<'EOF'
#!/bin/sh
{
  printf 'rm'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
EOF
chmod +x "$tmp/removepin/rm"
: > "$log"
env PATH="$tmp/removepin:$PATH" sh "$hook" remove >/dev/null 2>&1 \
  || fail "the hook remove path failed"
expect 'rm [-f] [/usr/local/bin/opencode] [/usr/share/applications/opencode.desktop]'

project="$home/project"
mkdir -p "$project"
printf 'hello\n' > "$project/file.txt"
consent="$config/kaadzos/opencode-consent"

: > "$log"
FAKE_ZENITY_QUESTION_EXIT=1 "$helper" "$project" >/dev/null 2>&1 \
  || fail "the helper failed after the consent dialog was cancelled"
expect 'zenity [--question] [--title=OpenCode first-run consent]'
expect "--default-cancel"
expect "$project"
expect_absent 'foot'
[ ! -e "$consent" ] || fail "a cancelled dialog recorded consent"

: > "$log"
FAKE_ZENITY_QUESTION_EXIT=0 "$helper" "$project" >/dev/null 2>&1 \
  || fail "the helper failed after consent"
expect "foot [-T] [OpenCode] [--working-directory=$project] [-e] [opencode]"
grep -Fqx "$project" "$consent" || fail "consent was not recorded"

: > "$log"
FAKE_ZENITY_QUESTION_EXIT=1 "$helper" "$project" >/dev/null 2>&1 \
  || fail "the helper failed on a second run"
expect_absent 'zenity'
expect 'foot'

other="$home/other"
mkdir -p "$other"
: > "$log"
FAKE_ZENITY_QUESTION_EXIT=0 "$helper" "$other" >/dev/null 2>&1 \
  || fail "the helper failed for a new project"
expect 'zenity'

for bad in '' '-rf' "$tmp/missing-directory"; do
  : > "$log"
  if "$helper" "$bad" >/dev/null 2>&1; then
    fail "an invalid project directory was accepted: $bad"
  fi
  expect_absent 'zenity'
done

mkdir "$tmp/noopencode"
for command in foot zenity notify-send; do
  cp "$bin/$command" "$tmp/noopencode/$command"
done
: > "$log"
if env PATH="$tmp/noopencode:/usr/bin:/bin" KAADZOS_TEST_LOG="$log" \
    HOME="$home" XDG_CONFIG_HOME="$config" \
    "$helper" "$project" >/dev/null 2>&1; then
  fail "the helper started without opencode installed"
fi

[ "$failed" -eq 0 ] || exit 1
echo "opencode pack is valid"
