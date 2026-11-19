#!/bin/sh
# Static desktop checks shared by the build and pack-test jobs. These catch a
# broken generated config or helper before the long ISO build and boot matrix.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
waybar="$root/config/includes.chroot/etc/skel/.config/waybar/config"
style="$root/config/includes.chroot/etc/skel/.config/waybar/style.css"
sway="$root/config/includes.chroot/etc/skel/.config/sway/config"
sway_overrides="$root/config/includes.chroot/etc/skel/.config/sway/config.d"
helper="$root/config/includes.chroot/usr/local/bin/kaadzos-bluetooth"
control="$root/config/includes.chroot/usr/local/bin/kaadzos-control"
control_desktop="$root/config/includes.chroot/usr/share/applications/kaadzos-control.desktop"
settings="$root/config/includes.chroot/usr/local/bin/kaadzos-settings"
settings_desktop="$root/config/includes.chroot/usr/share/applications/kaadzos-settings.desktop"
packages_cli="$root/config/includes.chroot/usr/local/bin/kaadzos-packages"
packages_desktop="$root/config/includes.chroot/usr/share/applications/kaadzos-packages.desktop"
search="$root/config/includes.chroot/usr/local/bin/kaadzos-search"
portal_conf="$root/config/includes.chroot/etc/xdg/xdg-desktop-portal/portals.conf"
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

# User overrides: only *.conf is included, the README stays inert, and the
# default file keeps the glob matching before settings writes anything.
grep -Fqx 'include ~/.config/sway/config.d/*.conf' "$sway" \
  || fail "Sway config must include the per-user config.d overrides"
grep -Fq 'include ~/.config/sway/config.d/*.conf' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the config.d include"
[ -f "$sway_overrides/README" ] || fail "config.d/README is missing"
[ -f "$sway_overrides/00-default.conf" ] || fail "config.d/00-default.conf is missing"

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

# Control centre: one helper, one launcher, one Sway binding and four Waybar
# modules. The modules must also be generated, so a theme regeneration cannot
# silently drop them from the committed skel config.
[ -x "$control" ] || fail "$control is not executable"
dash -n "$control" || fail "kaadzos-control does not parse as POSIX sh"
[ -f "$control_desktop" ] || fail "$control_desktop is missing"
grep -qx '^Exec=kaadzos-control$' "$control_desktop" \
  || fail "control desktop entry must run kaadzos-control"

count=$(grep -c '^bindsym \$mod+Shift+s exec kaadzos-control$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+Shift+s control binding"
grep -Fq 'bindsym \$mod+Shift+s exec kaadzos-control' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the control binding"

for module in '"custom/control"' '"backlight"' '"power-profiles-daemon"' \
              '"idle_inhibitor"'; do
  grep -q -- "$module" "$waybar" || fail "Waybar config is missing: $module"
  grep -q -- "$module" "$root/theme/generate.sh" \
    || fail "theme/generate.sh does not generate: $module"
done
grep -q '"on-click": "kaadzos-control"' "$waybar" \
  || fail "Waybar control module is not wired to kaadzos-control"
grep -q '"on-click": "kaadzos-control power"' "$waybar" \
  || fail "Waybar battery click must open the power section"
grep -q 'kaadzos-control power-profile' "$waybar" \
  || fail "Waybar power profile click is not wired to kaadzos-control"
grep -q 'nm-connection-editor.*kaadzos-control' "$waybar" \
  || fail "Waybar network click must fall back to the control centre"

for state in '#custom-control' '#backlight' '#power-profiles-daemon' \
             '#idle_inhibitor'; do
  grep -q -- "$state" "$style" || fail "Waybar style is missing: $state"
  grep -q -- "$state" "$root/theme/generate.sh" \
    || fail "theme/generate.sh does not generate: $state"
done

# The helper must probe optional commands instead of assuming they exist.
for tool in wpctl powerprofilesctl upower brightnessctl wlsunset; do
  grep -q "have $tool" "$control" \
    || fail "kaadzos-control must guard $tool with a command probe"
done

# Control centre packages belong to the base list, not a pack.
for package in upower power-profiles-daemon wlsunset zenity; do
  grep -qx -- "$package" "$packages" || fail "base.list.chroot is missing: $package"
done

# Settings: one helper, one launcher and one free Sway binding. It must write
# user overrides through config.d rather than editing the generated config.
[ -x "$settings" ] || fail "$settings is not executable"
dash -n "$settings" || fail "kaadzos-settings does not parse as POSIX sh"
[ -f "$settings_desktop" ] || fail "$settings_desktop is missing"
grep -qx '^Exec=kaadzos-settings$' "$settings_desktop" \
  || fail "settings desktop entry must run kaadzos-settings"
count=$(grep -c '^bindsym \$mod+comma exec kaadzos-settings$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+comma settings binding"
grep -Fq 'bindsym \$mod+comma exec kaadzos-settings' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the settings binding"
grep -q 'sway_dir/20-keyboard.conf' "$settings" \
  || fail "kaadzos-settings must persist the keyboard override in config.d"
grep -q 'kaadzos-file-action' "$settings" \
  || fail "kaadzos-settings must delegate wallpaper handling"
grep -q 'KAADZOS_SETTINGS_OK' "$session_ready" \
  || fail "kaadzos-session-ready must emit KAADZOS_SETTINGS_OK"
grep -q 'KAADZOS_SETTINGS_MISSING' "$session_ready" \
  || fail "kaadzos-session-ready must emit KAADZOS_SETTINGS_MISSING"
grep -Fq 'include ~/.config/sway/config.d/*.conf' "$session_ready" \
  || fail "kaadzos-session-ready must assert the config.d include"

# Packages: one base helper, one desktop entry, one Sway binding, one Waybar
# module and the Settings row. Synaptic itself stays in the admin pack.
[ -x "$packages_cli" ] || fail "$packages_cli is not executable"
dash -n "$packages_cli" || fail "kaadzos-packages does not parse as POSIX sh"
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$packages_cli"; then
  fail "kaadzos-packages must not use eval"
fi
[ -f "$packages_desktop" ] || fail "$packages_desktop is missing"
grep -qx '^Exec=kaadzos-packages$' "$packages_desktop" \
  || fail "packages desktop entry must run kaadzos-packages"
count=$(grep -c '^bindsym \$mod+Shift+p exec kaadzos-packages$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+Shift+p packages binding"
grep -Fq 'bindsym \$mod+Shift+p exec kaadzos-packages' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the packages binding"
grep -q '"custom/packages"' "$waybar" || fail "Waybar config is missing custom/packages"
grep -q '"custom/packages"' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate custom/packages"
grep -q '"on-click": "kaadzos-packages"' "$waybar" \
  || fail "Waybar packages module is not wired to kaadzos-packages"
grep -q '#custom-packages' "$style" || fail "Waybar style is missing #custom-packages"
grep -q '#custom-packages' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate #custom-packages"
grep -Fq '"Packages" "Software and optional packs"' "$settings" \
  || fail "kaadzos-settings is missing the Packages row"
grep -Fq 'packages) packages' "$settings" \
  || fail "kaadzos-settings is missing the packages subcommand"
[ -f "$root/packs/admin.pack" ] || fail "packs/admin.pack is missing"
grep -qx 'apt=synaptic pkexec lxpolkit' "$root/packs/admin.pack" \
  || fail "admin pack must provide Synaptic, pkexec and the polkit agent"
grep -Fq "command -v lxpolkit" "$sway" \
  || fail "Sway config must start lxpolkit when the admin pack provides it"
grep -Fq "command -v lxpolkit" "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the lxpolkit autostart"

# Search: Super+D is the smart search over apps/files/settings/packs and
# Super+Shift+D keeps the plain fuzzel launcher. The helper must not eval
# filenames and must bound its home scan.
[ -x "$search" ] || fail "$search is not executable"
dash -n "$search" || fail "kaadzos-search does not parse as POSIX sh"
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$search"; then
  fail "kaadzos-search must not use eval"
fi
count=$(grep -c '^bindsym \$mod+d exec kaadzos-search$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+d search binding"
count=$(grep -c '^bindsym \$mod+Shift+d exec \$launcher$' "$sway" || true)
[ "$count" -eq 1 ] || fail "Sway config needs exactly one \$mod+Shift+d launcher binding"
if grep -q '^bindsym \$mod+d exec \$launcher$' "$sway"; then
  fail "Sway config still binds \$mod+d to the plain launcher"
fi
grep -Fq 'bindsym \$mod+d exec kaadzos-search' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the search binding"
grep -Fq 'bindsym \$mod+Shift+d exec \$launcher' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the plain launcher binding"
for needle in 'fuzzel --dmenu' 'gio launch' 'xdg-open' 'kaadzos list' \
              'kaadzos-settings' 'kaadzos add' 'timeout 2 find'; do
  grep -Fq -- "$needle" "$search" || fail "kaadzos-search is missing: $needle"
done
for excluded in .ssh .gnupg node_modules .git keyrings google-chrome; do
  grep -Fq -- "$excluded" "$search" \
    || fail "kaadzos-search must exclude: $excluded"
done

# Portal/session integration: the portal packages are in base, the Sway config
# exports the Wayland environment to both the private dbus-run-session bus and
# the systemd user manager, and the backend selection is explicit.
for package in xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr; do
  grep -qx -- "$package" "$packages" || fail "base.list.chroot is missing: $package"
done
grep -q 'dbus-update-activation-environment WAYLAND_DISPLAY' "$sway" \
  || fail "Sway config must update the session bus activation environment"
grep -Eq 'timeout [0-9]+ dbus-update-activation-environment --systemd WAYLAND_DISPLAY' "$sway" \
  || fail "Sway config must update the systemd user activation environment"
grep -q 'XDG_CURRENT_DESKTOP=sway' "$sway" \
  || fail "Sway activation environment must name the desktop"
grep -Fq 'dbus-update-activation-environment WAYLAND_DISPLAY' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the session bus environment update"
grep -Eq 'timeout [0-9]+ dbus-update-activation-environment --systemd WAYLAND_DISPLAY' "$root/theme/generate.sh" \
  || fail "theme/generate.sh does not generate the systemd environment update"

[ -f "$portal_conf" ] || fail "$portal_conf is missing"
grep -qx '\[preferred\]' "$portal_conf" || fail "portals.conf is missing [preferred]"
grep -qx 'default=gtk' "$portal_conf" || fail "portals.conf must default to gtk"
grep -qx 'org.freedesktop.impl.portal.ScreenCast=wlr' "$portal_conf" \
  || fail "portals.conf must use wlr for ScreenCast"
grep -qx 'org.freedesktop.impl.portal.Screenshot=wlr' "$portal_conf" \
  || fail "portals.conf must use wlr for Screenshot"

grep -Eq 'timeout [0-9]+ gdbus call' "$session_ready" \
  || fail "kaadzos-session-ready must bound the portal activation check"
grep -q 'org.freedesktop.portal.Desktop' "$session_ready" \
  || fail "kaadzos-session-ready must assert the portal bus name"

[ "$failed" -eq 0 ] || exit 1
echo "desktop configuration is valid"
