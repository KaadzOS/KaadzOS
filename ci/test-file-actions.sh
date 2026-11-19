#!/bin/sh
# Functional checks for kaadzos-file-action without touching the host session.
# Fakes record every swaymsg call, and XDG_CONFIG_HOME points at a throwaway
# directory so the helper writes and rewrites only under the test tree.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-file-action"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
log="$tmp/commands.log"
mkdir -p "$bin" "$home" "$config"

export HOME="$home"
export XDG_CONFIG_HOME="$config"
export PATH="$bin:$PATH"
export KAADZOS_TEST_LOG="$log"

cat > "$bin/swaymsg" <<'EOF'
#!/bin/sh
{
  printf 'swaymsg'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
EOF
cat > "$bin/notify-send" <<'EOF'
#!/bin/sh
{
  printf 'notify-send'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
EOF
chmod +x "$bin/swaymsg" "$bin/notify-send"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

run() {
  : > "$log"
  "$helper" "$@" >/dev/null 2>&1 || fail "kaadzos-file-action $* exited nonzero"
}

expect_log() {
  grep -Fq -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

dash -n "$helper" || fail "kaadzos-file-action does not parse as POSIX sh"

override="$config/sway/config.d/10-wallpaper.conf"

plain="$tmp/wall paper.png"
printf 'png' > "$plain"
run wallpaper "$plain"
expect_log "swaymsg [output] [*] [bg] [$plain] [fill]"
grep -Fq "output * bg \"$plain\" fill" "$override" \
  || fail "wallpaper override does not contain the plain path"

quoted="$tmp/quote\"name.png"
printf 'png' > "$quoted"
run wallpaper "$quoted"
expect_log "swaymsg [output] [*] [bg] [$quoted] [fill]"
grep -Fq 'quote\"name.png' "$override" \
  || fail "wallpaper override does not escape the double quote"

unicode="$tmp/naïve.png"
printf 'png' > "$unicode"
run wallpaper "$unicode"
expect_log "swaymsg [output] [*] [bg] [$unicode] [fill]"
grep -Fq "$unicode" "$override" \
  || fail "wallpaper override does not preserve Unicode"

ln -s "$plain" "$tmp/link.png"
run wallpaper "$tmp/link.png"
expect_log "swaymsg [output] [*] [bg] [$tmp/link.png] [fill]"

bad=$(printf 'bad\nname.png')
printf 'png' > "$tmp/$bad"
: > "$log"
if "$helper" wallpaper "$tmp/$bad" >/dev/null 2>&1; then
  fail "a newline in the path must be rejected"
fi
if grep -Fq 'swaymsg' "$log"; then
  fail "a rejected newline path still reached swaymsg"
fi

printf 'png' > "$tmp/-rf"
: > "$log"
if (cd "$tmp" && "$helper" wallpaper -rf) >/dev/null 2>&1; then
  fail "a path beginning with '-' must be rejected"
fi
if grep -Fq 'swaymsg' "$log"; then
  fail "a rejected leading-dash path still reached swaymsg"
fi

mkdir "$tmp/dir"
if "$helper" wallpaper "$tmp/dir" >/dev/null 2>&1; then
  fail "a directory must be rejected"
fi
if "$helper" wallpaper "$tmp/missing.png" >/dev/null 2>&1; then
  fail "a missing file must be rejected"
fi
if "$helper" wallpaper >/dev/null 2>&1; then
  fail "a missing argument must be rejected"
fi
if "$helper" nonsense "$plain" >/dev/null 2>&1; then
  fail "an unknown action must be rejected"
fi

[ "$failed" -eq 0 ] || exit 1
echo "file actions are valid"
