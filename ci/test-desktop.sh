#!/bin/sh
# Static desktop checks shared by the build and pack-test jobs. These catch a
# broken generated config or helper before the long ISO build and boot matrix.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
waybar="$root/config/includes.chroot/etc/skel/.config/waybar/config"
style="$root/config/includes.chroot/etc/skel/.config/waybar/style.css"
sway="$root/config/includes.chroot/etc/skel/.config/sway/config"
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-bluetooth"
session_ready="$root/config/includes.chroot/usr/local/bin/kaadzos-session-ready"
hook="$root/config/hooks/live/0800-bluetooth.hook.chroot"
packages="$root/config/package-lists/base.list.chroot"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for the Waybar JSON check" >&2
  exit 1
fi

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

# The Waybar config is JSON, not a shell fragment, so parse it for real.
if ! python3 -m json.tool "$waybar" >/dev/null; then
  fail "Waybar config does not parse as JSON"
fi

# The Bluetooth module must be in the bar and wired to the shared helper.
for needle in '"bluetooth"' 'kaadzos-bluetooth manager' 'kaadzos-bluetooth toggle'; do
  grep -q -- "$needle" "$waybar" || fail "Waybar config is missing: $needle"
  grep -q -- "$needle" "$root/theme/generate.sh" \
    || fail "theme/generate.sh does not generate: $needle"
done

# State styling covers powered-off, unavailable and scanning.
for state in '#bluetooth.connected' '#bluetooth.discovering' '#bluetooth.off' \
             '#bluetooth.no-controller' '#bluetooth.disabled'; do
  grep -q -- "$state" "$style" || fail "Waybar style is missing: $state"
  grep -q -- "$state" "$root/theme/generate.sh" \
    || fail "theme/generate.sh does not generate: $state"
done

# The Sway binding must exist exactly once; a duplicate would trip swaynag.
count=$(grep -c '^bindsym \$mod+x exec kaadzos-bluetooth manager$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+x Bluetooth binding"

# New helpers and hooks are POSIX sh and executable in the image.
for script in "$helper" "$hook"; do
  [ -x "$script" ] || fail "$script is not executable"
  dash -n "$script" || fail "$script does not parse as POSIX sh"
done
dash -n "$session_ready" || fail "kaadzos-session-ready does not parse as POSIX sh"

# Never call bluetoothctl unbounded: when bluetoothd is inactive (no adapter)
# the client waits for the daemon instead of returning.
grep -q 'timeout 10 bluetoothctl' "$helper" \
  || fail "kaadzos-bluetooth must bound bluetoothctl with a timeout"
if grep -Eq '^[[:space:]]*bluetoothctl[[:space:]]' "$helper"; then
  fail "kaadzos-bluetooth calls bluetoothctl without a timeout"
fi
grep -q 'timeout 5 bluetoothctl list' "$session_ready" \
  || fail "kaadzos-session-ready must bound bluetoothctl list with a timeout"

# The Bluetooth packages must actually be part of the base list.
for package in bluez blueman dconf-gsettings-backend libglib2.0-bin; do
  grep -qx -- "$package" "$packages" || fail "base.list.chroot is missing: $package"
done

[ "$failed" -eq 0 ] || exit 1
echo "desktop configuration is valid"
