#!/bin/sh
# Functional checks for kaadzos-settings without touching the host session.
# Every external command is a fake first in PATH, and XDG_CONFIG_HOME points
# at a throwaway tree so overrides and settings.conf stay under the test.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-settings"
file_action="$root/config/includes.chroot/usr/local/bin/kaadzos-file-action"

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
export KAADZOS_FILE_ACTION="$file_action"
export KAADZOS_OS_RELEASE="$tmp/os-release"

cat > "$tmp/os-release" <<'EOF'
PRETTY_NAME="KaadzOS 0.4 test"
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

for command in gsettings xdg-settings xdg-mime swaymsg notify-send \
               kaadzos-control kaadzos-bluetooth nmcli pavucontrol wlr-randr; do
  write_logger "$command"
done

cat > "$bin/gsettings" <<'EOF'
#!/bin/sh
{
  printf 'gsettings'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
if [ "${1:-}" = get ]; then
  printf "%s\n" "${FAKE_GSETTINGS_GET:-'Inter Tight 11'}"
fi
EOF
chmod +x "$bin/gsettings"

cat > "$bin/zenity" <<'EOF'
#!/bin/sh
{
  printf 'zenity'
  for arg in "$@"; do printf ' [%s]' "$arg"; done
  printf '\n'
} >> "$KAADZOS_TEST_LOG"
if [ "${FAKE_ZENITY_CANCEL:-0}" = 1 ]; then
  exit 1
fi
for arg in "$@"; do
  case $arg in
    --list) printf '%s\n' "${FAKE_ZENITY_CHOICE:-}"; exit 0 ;;
    --entry) printf '%s\n' "${FAKE_ZENITY_ENTRY:-}"; exit 0 ;;
    --file-selection) printf '%s\n' "${FAKE_ZENITY_FILE:-}"; exit 0 ;;
    --info|--text-info) exit 0 ;;
    --question) exit 0 ;;
  esac
done
exit 0
EOF
chmod +x "$bin/zenity"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

run() {
  : > "$log"
  "$helper" "$@" >/dev/null 2>&1 || fail "kaadzos-settings $* exited nonzero"
}

expect() {
  grep -Fq -- "$1" "$log" || {
    fail "expected command: $1"
    sed 's/^/  got: /' "$log" >&2
  }
}

dash -n "$helper" || fail "kaadzos-settings does not parse as POSIX sh"

state="$config/kaadzos/settings.conf"
sway_dir="$config/sway/config.d"

run keyboard us
expect 'swaymsg [input] [type:keyboard] [xkb_layout] [us]'
grep -Fq 'xkb_layout "us"' "$sway_dir/20-keyboard.conf" \
  || fail "keyboard override was not written"
grep -Fq 'keyboard_layout=us' "$state" \
  || fail "keyboard setting was not persisted"

: > "$log"
if "$helper" keyboard 'bad layout' >/dev/null 2>&1; then
  fail "an invalid keyboard layout must be rejected"
fi
if grep -Fq 'swaymsg' "$log"; then
  fail "an invalid keyboard layout still reached swaymsg"
fi

run touchpad on
expect 'swaymsg [input] [type:touchpad] [tap] [enabled]'
grep -Fq 'tap enabled' "$sway_dir/20-touchpad.conf" \
  || fail "touchpad override was not written"
grep -Fq 'touchpad_tap=on' "$state" \
  || fail "touchpad setting was not persisted"

run touchpad off
expect 'swaymsg [input] [type:touchpad] [tap] [disabled]'
grep -Fq 'tap disabled' "$sway_dir/20-touchpad.conf" \
  || fail "touchpad override was not updated"

run dark-style
expect 'gsettings [set] [org.gnome.desktop.interface] [color-scheme] [prefer-dark]'
expect 'gsettings [set] [org.gnome.desktop.interface] [gtk-theme] [Adwaita]'

run light-style
expect 'gsettings [set] [org.gnome.desktop.interface] [color-scheme] [default]'

FAKE_ZENITY_ENTRY='Inter Tight 12'
export FAKE_ZENITY_ENTRY
run font
expect 'gsettings [set] [org.gnome.desktop.interface] [font-name] [Inter Tight 12]'

FAKE_ZENITY_ENTRY=Adwaita
export FAKE_ZENITY_ENTRY
run icons
expect 'gsettings [set] [org.gnome.desktop.interface] [icon-theme] [Adwaita]'

run browser
expect 'xdg-settings [set] [default-web-browser] [epiphany.desktop]'

run file-manager
expect 'xdg-mime [default] [thunar.desktop] [inode/directory]'

run about
expect 'zenity [--info] [--no-markup] [--title=About KaadzOS]'
grep -Fq 'KaadzOS 0.4 test' "$log" \
  || fail "About did not read the os-release fixture"

FAKE_ZENITY_CHOICE=About
export FAKE_ZENITY_CHOICE
run
expect 'zenity [--info] [--no-markup] [--title=About KaadzOS]'

FAKE_ZENITY_CANCEL=1
export FAKE_ZENITY_CANCEL
: > "$log"
run
if grep -Fq 'gsettings [set]' "$log"; then
  fail "a cancelled menu still changed a setting"
fi

unset FAKE_ZENITY_CANCEL

run display
expect 'wlr-randr'
expect 'zenity [--text-info] [--title=Display]'
write_logger nwg-displays
run display
expect 'nwg-displays'

run network
expect 'nmcli [device] [status]'
expect 'zenity [--text-info] [--title=Network]'
write_logger nm-connection-editor
run network
expect 'nm-connection-editor'

run bluetooth
expect 'kaadzos-bluetooth [manager]'

run sound
expect 'pavucontrol'

run power
expect 'kaadzos-control [power]'

image="$tmp/wall paper.png"
printf 'png' > "$image"
run wallpaper "$image"
expect "swaymsg [output] [*] [bg] [$image] [fill]"
grep -Fq "output * bg \"$image\" fill" "$sway_dir/10-wallpaper.conf" \
  || fail "wallpaper override was not written"
grep -Fq "wallpaper=$image" "$state" \
  || fail "wallpaper setting was not persisted"

if "$helper" nonsense >/dev/null 2>&1; then
  fail "an unknown action must be rejected"
fi

[ "$failed" -eq 0 ] || exit 1
echo "settings actions are valid"
