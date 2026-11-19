#!/bin/sh
# Static checks for the installed greetd/tuigreet path. They catch a lost
# AMOLED theme, a missing greeting or time format, and a Plymouth race before
# the long install matrix runs.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
finalize="$root/config/includes.chroot/usr/local/bin/kaadzos-install-finalize"
displaymanager="$root/config/includes.chroot/etc/calamares/modules/displaymanager.conf"
session="$root/config/includes.chroot/usr/local/bin/kaadzos-sway-session"
session_ready="$root/config/includes.chroot/usr/local/bin/kaadzos-session-ready"
quit_unit="$root/config/includes.chroot/etc/systemd/system/kaadzos-quit-plymouth.service"
greetd_dropin="$root/config/includes.chroot/etc/systemd/system/greetd.service.d/kaadzos-plymouth.conf"
install_test="$root/ci/test-install.sh"

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

for script in "$finalize" "$session" "$session_ready"; do
  [ -x "$script" ] || fail "$script is not executable"
  dash -n "$script" || fail "$script does not parse as POSIX sh"
done

# The Calamares displaymanager module must keep the Sway wrapper and Debian's
# _greetd account; the finalize hook pins the VT and decorates tuigreet.
grep -q 'executable: "/usr/local/bin/kaadzos-sway-session"' "$displaymanager" \
  || fail "displaymanager must use the KaadzOS Sway wrapper"
grep -q 'greeter_user: "_greetd"' "$displaymanager" \
  || fail "displaymanager must use the Debian _greetd user"
grep -q 'greeter_group: "_greetd"' "$displaymanager" \
  || fail "displaymanager must use the Debian _greetd group"

grep -Fq 'terminal["vt"] = 7' "$finalize" \
  || fail "kaadzos-install-finalize must pin VT 7"
for needle in '--theme' '--greeting' '--time-format'; do
  grep -Fq -- "$needle" "$finalize" \
    || fail "kaadzos-install-finalize is missing $needle"
done
for token in 'border=white' 'text=white' 'time=white' 'container=black' \
             'title=white' 'greet=gray' 'prompt=white' 'input=white' \
             'action=gray' 'button=white'; do
  grep -Fq "$token" "$finalize" || fail "tuigreet theme is missing $token"
done
grep -Fq "KaadzOS" "$finalize" || fail "tuigreet greeting is missing KaadzOS"
grep -Fq '%a %d %b  %H:%M' "$finalize" \
  || fail "tuigreet time format does not match the Waybar clock"

# Plymouth must be released before Sway or greetd takes the DRM master.
grep -n 'plymouth quit' "$session" | grep -q . \
  || fail "the session wrapper must quit Plymouth defensively"
plymouth_line=$(grep -n 'plymouth quit' "$session" | cut -d: -f1 | head -n 1)
sway_line=$(grep -n 'dbus-run-session -- sway' "$session" | cut -d: -f1 | head -n 1)
[ -n "$plymouth_line" ] && [ -n "$sway_line" ] \
  || fail "the session wrapper is missing its Plymouth or Sway launch"
[ "$plymouth_line" -lt "$sway_line" ] \
  || fail "Plymouth must be quit before Sway starts"
grep -q 'Before=getty.target' "$quit_unit" \
  || fail "kaadzos-quit-plymouth.service must run before getty.target"
grep -q 'After=kaadzos-quit-plymouth.service' "$greetd_dropin" \
  || fail "greetd must start after kaadzos-quit-plymouth.service"

# The installed session must assert the final greeter config, and the install
# job must require that marker.
grep -q 'KAADZOS_GREETER_OK' "$session_ready" \
  || fail "kaadzos-session-ready must emit KAADZOS_GREETER_OK"
grep -q 'KAADZOS_GREETER_MISSING' "$session_ready" \
  || fail "kaadzos-session-ready must emit KAADZOS_GREETER_MISSING"
grep -q 'KAADZOS_GREETER_OK' "$install_test" \
  || fail "test-install.sh must require KAADZOS_GREETER_OK"
grep -q 'KAADZOS_GREETER_MISSING' "$install_test" \
  || fail "test-install.sh must fail on KAADZOS_GREETER_MISSING"

[ "$failed" -eq 0 ] || exit 1
echo "greeter configuration is valid"
