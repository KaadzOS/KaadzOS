#!/bin/sh
# Functional checks for kaadzos-control without touching the host session.
# Every external command is a fake first in PATH; the helper must call only
# the fake, which records its arguments. This exercises the menu dispatch,
# power-profile cycle, confirmation path and direct action entry points.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-control"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
home="$tmp/home"
log="$tmp/commands.log"
mkdir -p "$bin" "$home"

export HOME="$home"
export TMPDIR="$tmp"
export KAADZOS_TEST_LOG="$log"
export PATH="$bin:$PATH"

write_logger() {
  name=$1
  cat > "$bin/$name" <<EOF
#!/bin/sh
printf '%s %s\\n' "$name" "\$*" >> "\$KAADZOS_TEST_LOG"
EOF
  chmod +x "$bin/$name"
}

for command in wpctl brightnessctl systemctl swaylock swaymsg pavucontrol \
               upower nmcli nm-connection-editor kaadzos-bluetooth \
               kaadzos-screenshot kaadzos-record kaadzos-settings \
               notify-send; do
  write_logger "$command"
done

cat > "$bin/powerprofilesctl" <<'EOF'
#!/bin/sh
case ${1:-} in
  get) printf '%s\n' "${FAKE_POWER_PROFILE:-balanced}" ;;
  set) printf 'powerprofilesctl set %s\n' "${2:-}" >> "$KAADZOS_TEST_LOG" ;;
esac
EOF

cat > "$bin/zenity" <<'EOF'
#!/bin/sh
printf 'zenity %s\n' "$*" >> "$KAADZOS_TEST_LOG"
for arg in "$@"; do
  case $arg in
    --question)
      [ "${FAKE_ZENITY_QUESTION:-1}" = 0 ] && exit 0
      exit 1
      ;;
    --list)
      [ "${FAKE_ZENITY_CANCEL:-0}" = 1 ] && exit 1
      printf '%s\n' "${FAKE_ZENITY_CHOICE:-}"
      exit 0
      ;;
  esac
done
exit 0
EOF

cat > "$bin/fuzzel" <<'EOF'
#!/bin/sh
printf 'fuzzel %s\n' "$*" >> "$KAADZOS_TEST_LOG"
printf '%s\n' "${FAKE_FUZZEL_CHOICE:-}"
EOF

chmod +x "$bin/powerprofilesctl" "$bin/zenity" "$bin/fuzzel"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

run() {
  : > "$log"
  "$helper" "$@" >/dev/null 2>&1 || fail "kaadzos-control $* exited nonzero"
}

expect() {
  grep -Fqx -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

dash -n "$helper" || fail "kaadzos-control does not parse as POSIX sh"

run audio-mute
expect 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'

run mic-mute
expect 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'

run volume-up
expect 'wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+'

run volume-down
expect 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'

FAKE_POWER_PROFILE=performance
export FAKE_POWER_PROFILE
run power-profile
expect 'powerprofilesctl set balanced'

FAKE_ZENITY_QUESTION=1
export FAKE_ZENITY_QUESTION
run poweroff
if grep -Fq 'systemctl poweroff' "$log"; then
  fail "cancelled poweroff still called systemctl"
fi

FAKE_ZENITY_QUESTION=0
export FAKE_ZENITY_QUESTION
run reboot
expect 'systemctl reboot'

FAKE_ZENITY_CHOICE='Audio: mute output'
export FAKE_ZENITY_CHOICE
run
expect 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'

FAKE_ZENITY_CHOICE='Session: lock'
export FAKE_ZENITY_CHOICE
run
expect 'swaylock -f'

FAKE_ZENITY_CHOICE='Printers: manage'
export FAKE_ZENITY_CHOICE
run
expect 'kaadzos-settings printers'

FAKE_ZENITY_CHOICE='Hardware: tools'
export FAKE_ZENITY_CHOICE
run
expect 'kaadzos-settings hardware'

run printers
expect 'kaadzos-settings printers'

run hardware
expect 'kaadzos-settings hardware'

FAKE_ZENITY_CHOICE=''
FAKE_ZENITY_CANCEL=1
export FAKE_ZENITY_CHOICE FAKE_ZENITY_CANCEL
run
if grep -Fq 'wpctl ' "$log"; then
  fail "cancelled menu still performed an action"
fi

if "$helper" nonsense >/dev/null 2>&1; then
  fail "unknown action must exit nonzero"
fi

[ "$failed" -eq 0 ] || exit 1
echo "control centre actions are valid"
