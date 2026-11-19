#!/bin/sh
# Functional checks for kaadzos-search without opening fuzzel or touching the
# host session. The fake fuzzel records the candidate stream and returns a
# chosen line; every dispatcher is a fake first in PATH.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-search"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
home="$tmp/home"
data="$tmp/data"
system="$tmp/system"
log="$tmp/commands.log"
candidates="$tmp/candidates"
mkdir -p "$bin" "$home/Documents" "$home/Pictures" "$home/.ssh" \
  "$home/project/node_modules" "$home/project/.git" \
  "$home/.local/share" "$home/.config/google-chrome" \
  "$data/applications" "$system/applications"

export HOME="$home"
export XDG_DATA_HOME="$data"
export XDG_DATA_DIRS="$system"
export PATH="$bin:$PATH"
export KAADZOS_TEST_LOG="$log"
export KAADZOS_TEST_CANDIDATES="$candidates"

printf 'x' > "$home/Documents/hello world.txt"
printf 'x' > "$home/Pictures/naïve.png"
printf 'x' > "$home/.ssh/secret.txt"
printf 'x' > "$home/project/node_modules/hidden.js"
printf 'x' > "$home/project/.git/config"
printf 'x' > "$home/.config/google-chrome/History"
printf 'x' > "$tmp/recent-only.txt"
bad=$(printf 'badnewlinefile\n.txt')
printf 'x' > "$home/$bad"

cat > "$data/applications/test.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Test App
Exec=true
EOF

cat > "$data/recently-used.xbel" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file://$home/Documents/hello%20world.txt" />
  <bookmark href="file://$home/Pictures/na%C3%AFve.png" />
  <bookmark href="file://$tmp/recent-only.txt" />
</xbel>
EOF

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

for command in gio xdg-open kaadzos-settings kaadzos-control foot \
               swaymsg swaylock kaadzos-install notify-send; do
  write_logger "$command"
done

cat > "$bin/kaadzos" <<'EOF'
#!/bin/sh
case ${1:-} in
  list) printf 'PACK         STATUS     DESCRIPTION\n'
        printf 'dev          available  Development\n' ;;
esac
EOF
chmod +x "$bin/kaadzos"

cat > "$bin/fuzzel" <<'EOF'
#!/bin/sh
cat > "$KAADZOS_TEST_CANDIDATES"
if [ -n "${FAKE_FUZZEL_CHOICE:-}" ]; then
  printf '%s\n' "$FAKE_FUZZEL_CHOICE"
  exit 0
fi
exit 1
EOF
chmod +x "$bin/fuzzel"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

tab=$(printf '\t')

dash -n "$helper" || fail "kaadzos-search does not parse as POSIX sh"
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$helper"; then
  fail "kaadzos-search must not use eval"
fi

run_candidates() {
  : > "$candidates"
  : > "$log"
  FAKE_FUZZEL_CHOICE=
  export FAKE_FUZZEL_CHOICE
  if ! "$helper" >/dev/null 2>"$tmp/helper.err"; then
    fail "kaadzos-search exited nonzero while building candidates"
    sed 's/^/  err: /' "$tmp/helper.err" >&2
  fi
}

expect_candidate() {
  grep -Fq -- "$1" "$candidates" || {
    fail "missing candidate: $1"
    sed 's/^/  got: /' "$candidates" >&2
  }
}

expect_absent() {
  if grep -Fq -- "$1" "$candidates"; then
    fail "unexpected candidate: $1"
  fi
}

dispatch_test() {
  choice=$1
  expected=$2
  : > "$log"
  FAKE_FUZZEL_CHOICE=$choice
  export FAKE_FUZZEL_CHOICE
  if ! "$helper" >/dev/null 2>"$tmp/helper.err"; then
    fail "kaadzos-search exited nonzero for: $expected"
    sed 's/^/  err: /' "$tmp/helper.err" >&2
  fi
  grep -Fq -- "$expected" "$log" || {
    fail "expected command: $expected"
    sed 's/^/  got: /' "$log" >&2
  }
}

run_candidates
expect_candidate "App${tab}Test App${tab}$data/applications/test.desktop"
expect_candidate "File${tab}hello world.txt${tab}$home/Documents/hello world.txt"
expect_candidate "File${tab}naïve.png${tab}$home/Pictures/naïve.png"
expect_candidate "File${tab}recent-only.txt${tab}$tmp/recent-only.txt"
expect_candidate "Setting${tab}Appearance${tab}appearance"
expect_candidate "Pack${tab}dev${tab}dev"
expect_candidate "Command${tab}Control Centre${tab}control"
expect_candidate "Command${tab}Install KaadzOS${tab}install"

for needle in secret.txt hidden.js '.git/config' 'google-chrome/History' badnewlinefile; do
  expect_absent "$needle"
done

dispatch_test "App${tab}Test App${tab}$data/applications/test.desktop" \
  "gio [launch] [$data/applications/test.desktop]"
dispatch_test "File${tab}hello world.txt${tab}$home/Documents/hello world.txt" \
  "xdg-open [$home/Documents/hello world.txt]"
dispatch_test "File${tab}naïve.png${tab}$home/Pictures/naïve.png" \
  "xdg-open [$home/Pictures/naïve.png]"
dispatch_test "Setting${tab}Display${tab}display" \
  "kaadzos-settings [display]"
dispatch_test "Pack${tab}dev${tab}dev" \
  "foot [-T] [Install dev] [-e] [kaadzos] [add] [dev]"
dispatch_test "Command${tab}Lock screen${tab}lock" \
  "swaylock [-f]"
dispatch_test "Command${tab}Control Centre${tab}control" \
  "kaadzos-control"
dispatch_test "Command${tab}Reload Sway${tab}reload" \
  "swaymsg [reload]"
dispatch_test "Command${tab}Install KaadzOS${tab}install" \
  "kaadzos-install"

: > "$log"
FAKE_FUZZEL_CHOICE=
export FAKE_FUZZEL_CHOICE
"$helper" >/dev/null 2>&1 || fail "kaadzos-search exited nonzero on cancel"
if grep -Eq 'gio \[|xdg-open \[|kaadzos-settings \[|foot \[' "$log"; then
  fail "a cancelled search still dispatched an action"
fi

rm -f "$data/recently-used.xbel"
run_candidates
expect_candidate "File${tab}hello world.txt${tab}$home/Documents/hello world.txt"
expect_absent "File${tab}recent-only.txt${tab}$tmp/recent-only.txt"

FAKE_FUZZEL_CHOICE="Bogus${tab}x${tab}y"
export FAKE_FUZZEL_CHOICE
if "$helper" >/dev/null 2>&1; then
  fail "an unknown candidate must be rejected"
fi

[ "$failed" -eq 0 ] || exit 1
echo "search candidates and dispatch are valid"
