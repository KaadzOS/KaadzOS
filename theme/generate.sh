#!/usr/bin/env bash
# Generate every themed config from theme/palette into config/includes.chroot.
# Run from the repo root:  sh theme/generate.sh
# Re-run after editing theme/palette to propagate colours everywhere.
set -Eeuo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/.." && pwd)
# shellcheck source=palette
. "$here/palette"

chroot="$root/config/includes.chroot"
sys="$chroot/etc"                                # system-wide configs (GTK)
cfg="$chroot/etc/skel/.config"                    # per-user configs (copied to $HOME)
wall_dir="$chroot/usr/share/backgrounds/kaadzos"
# Path as it appears inside the running guest (never a build-machine path).
wall_guest="/usr/share/backgrounds/kaadzos"

mkdir -p \
  "$cfg/sway" "$cfg/waybar" "$cfg/foot" "$cfg/fuzzel" "$cfg/mako" \
  "$cfg/swaylock" "$cfg/qt6ct" "$sys/qt6ct/colors" \
  "$sys/gtk-3.0" "$sys/gtk-4.0" "$sys/systemd/system" \
  "$wall_dir" "$chroot/usr/local/share/kaadzos"

# foot/swaylock want RRGGBB without a leading '#'; the rest want '#RRGGBB'.
strip() { printf '%s' "${1#\#}"; }

# ------------------------------------------------------------------- wallpaper
cat > "$wall_dir/wallpaper.svg" <<SVG
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <radialGradient id="glow" cx="72%" cy="28%" r="90%">
      <stop offset="0%" stop-color="${KAADZ_ACCENT}" stop-opacity="0.30"/>
      <stop offset="45%" stop-color="${KAADZ_ACCENT_ALT}" stop-opacity="0.10"/>
      <stop offset="100%" stop-color="${KAADZ_BG}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${KAADZ_BG_ALT}"/>
      <stop offset="100%" stop-color="${KAADZ_BG}"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#base)"/>
  <rect width="1920" height="1080" fill="url(#glow)"/>
  <g stroke="${KAADZ_BORDER}" stroke-opacity="0.35" fill="none">
    <path d="M0 760 L520 560 L1040 700 L1560 480 L1920 600" stroke-width="2"/>
    <path d="M0 860 L520 660 L1040 800 L1560 580 L1920 700" stroke-width="1" stroke-opacity="0.2"/>
  </g>
  <g fill="${KAADZ_ACCENT}">
    <circle cx="1382" cy="302" r="4" opacity="0.9"/>
    <circle cx="1382" cy="302" r="46" opacity="0.12"/>
  </g>
</svg>
SVG

# ------------------------------------------------------------------------ sway
cat > "$cfg/sway/config" <<SWAY
# KaadzOS Sway configuration (generated from theme/palette).
set \$mod Mod4
set \$term foot
set \$launcher fuzzel
set \$lock swaylock
set \$browser xdg-open

font pango:${KAADZ_FONT_UI} ${KAADZ_FONT_SIZE}

# Wallpaper + idle behaviour
output * bg ${wall_guest}/wallpaper.png fill
exec swayidle -w timeout 600 'swaylock -f' lock 'swaylock -f' before-sleep 'swaylock -f'

# Input
input type:keyboard {
    xkb_layout us
}
input type:touchpad {
    tap enabled
    natural_scroll enabled
}

# Appearance
client.focused          ${KAADZ_ACCENT} ${KAADZ_SURFACE} ${KAADZ_FG} ${KAADZ_ACCENT} ${KAADZ_ACCENT}
client.focused_inactive ${KAADZ_BORDER} ${KAADZ_BG_ALT} ${KAADZ_FG_MUTED} ${KAADZ_BORDER} ${KAADZ_BORDER}
client.unfocused        ${KAADZ_BORDER} ${KAADZ_BG} ${KAADZ_FG_MUTED} ${KAADZ_BORDER} ${KAADZ_BORDER}
client.urgent           ${KAADZ_URGENT} ${KAADZ_URGENT} ${KAADZ_URGENT_FG} ${KAADZ_URGENT} ${KAADZ_URGENT}
client.placeholder      ${KAADZ_BG} ${KAADZ_BG} ${KAADZ_FG} ${KAADZ_BG} ${KAADZ_BG}
default_border pixel 2
default_floating_border pixel 2
gaps inner 6
gaps outer 2
smart_gaps on

# The welcome terminal floats centred so the wallpaper stays visible.
for_window [app_id="foot" title="KaadzOS Terminal"] floating enable, resize set 1100 690, move position center

# Autostart (logs go to /tmp; /run/hostshare only exists in the QEMU boot test)
exec waybar >/tmp/waybar.log 2>&1
exec mako >/tmp/mako.log 2>&1
exec foot --title "KaadzOS Terminal"
exec sh /usr/local/bin/kaadzos-session-ready

# Launchers / system
bindsym \$mod+Return exec \$term
bindsym \$mod+d exec \$launcher
bindsym \$mod+q kill
bindsym \$mod+Shift+e exec swaynag -t warning -m 'Exit KaadzOS?' -b 'Power off' 'poweroff' -b 'Reboot' 'reboot' -b 'Log out' 'exit'
bindsym \$mod+Shift+l exec \$lock
bindsym \$mod+Shift+c reload
bindsym \$mod+Shift+r exec swaymsg restart

# Focus
bindsym \$mod+h focus left
bindsym \$mod+j focus down
bindsym \$mod+k focus up
bindsym \$mod+l focus right
bindsym \$mod+Left focus left
bindsym \$mod+Down focus down
bindsym \$mod+Up focus up
bindsym \$mod+Right focus right

# Move
bindsym \$mod+Shift+h move left
bindsym \$mod+Shift+j move down
bindsym \$mod+Shift+k move up
bindsym \$mod+Shift+l move right

# Layout
bindsym \$mod+b splith
bindsym \$mod+v splitv
bindsym \$mod+s layout stacking
bindsym \$mod+w layout tabbed
bindsym \$mod+e layout toggle split
bindsym \$mod+f fullscreen
bindsym \$mod+Shift+space floating toggle
bindsym \$mod+space focus mode_toggle

# Workspaces
bindsym \$mod+1 workspace number 1
bindsym \$mod+2 workspace number 2
bindsym \$mod+3 workspace number 3
bindsym \$mod+4 workspace number 4
bindsym \$mod+5 workspace number 5
bindsym \$mod+6 workspace number 6
bindsym \$mod+7 workspace number 7
bindsym \$mod+8 workspace number 8
bindsym \$mod+9 workspace number 9
bindsym \$mod+0 workspace number 10
bindsym \$mod+Shift+1 move container to workspace number 1
bindsym \$mod+Shift+2 move container to workspace number 2
bindsym \$mod+Shift+3 move container to workspace number 3
bindsym \$mod+Shift+4 move container to workspace number 4
bindsym \$mod+Shift+5 move container to workspace number 5
bindsym \$mod+Shift+6 move container to workspace number 6
bindsym \$mod+Shift+7 move container to workspace number 7
bindsym \$mod+Shift+8 move container to workspace number 8
bindsym \$mod+Shift+9 move container to workspace number 9
bindsym \$mod+Shift+0 move container to workspace number 10
bindsym \$mod+Tab workspace next
bindsym \$mod+Shift+Tab workspace prev

# Screenshots
bindsym Print exec kaadzos-screenshot full
bindsym Shift+Print exec kaadzos-screenshot region

# Media keys
bindsym XF86AudioRaiseVolume exec wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set 5%+ 2>/dev/null || true
bindsym XF86MonBrightnessDown exec brightnessctl set 5%- 2>/dev/null || true

# Resize mode
mode "resize" {
    bindsym h resize shrink width 20 px
    bindsym j resize grow height 20 px
    bindsym k resize shrink height 20 px
    bindsym l resize grow width 20 px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym \$mod+r mode "resize"
SWAY

# ---------------------------------------------------------------------- waybar
mkdir -p "$cfg/waybar"
cat > "$cfg/waybar/config" <<WBAR
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 0,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["network", "pulseaudio", "battery", "tray"],
    "sway/workspaces": {
        "format": "{name}",
        "all-outputs": true,
        "persistent-workspaces": { "1": [], "2": [], "3": [], "4": [], "5": [] }
    },
    "sway/mode": { "format": " {} " },
    "clock": {
        "format": "{:%a %d %b  %H:%M}",
        "tooltip-format": "<tt>{calendar}</tt>",
        "calendar": { "mode": "month" }
    },
    "network": {
        "format-wifi": "\uf1eb {essid}",
        "format-ethernet": "\uf1e6 {ifname}",
        "format-disconnected": "\uf127 offline",
        "tooltip-format": "{ipaddr}/{cidr}"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "\uf026 muted",
        "format-icons": ["\uf026", "\uf027", "\uf028"],
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "on-click-right": "pavucontrol || foot -T Volume -e wpctl status"
    },
    "battery": {
        "states": { "good": 80, "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-charging": "\uf0e7 {capacity}%",
        "format-icons": ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
        "tooltip-format": "{timeTo} remaining"
    },
    "tray": { "icon-size": 18, "spacing": 8 }
}
WBAR

cat > "$cfg/waybar/style.css" <<WCSS
/* KaadzOS Waybar (generated from theme/palette). */
* {
    border: none;
    border-radius: 0;
    font-family: "${KAADZ_FONT_UI}", "FontAwesome", "${KAADZ_FONT_FALLBACK}";
    font-size: ${KAADZ_FONT_SIZE}px;
    min-height: 0;
}
window#waybar {
    background: ${KAADZ_BG_ALT};
    color: ${KAADZ_FG};
    border-bottom: 2px solid ${KAADZ_BORDER};
}
#workspaces button {
    padding: 0 10px;
    color: ${KAADZ_FG_MUTED};
    background: transparent;
}
#workspaces button.focused,
#workspaces button.current,
#workspaces button.visible {
    color: ${KAADZ_ACCENT};
    border-bottom: 2px solid ${KAADZ_ACCENT};
}
#workspaces button.urgent { color: ${KAADZ_URGENT}; }
#mode {
    background: ${KAADZ_ACCENT_ALT};
    color: ${KAADZ_URGENT_FG};
    padding: 0 10px;
}
#clock, #network, #pulseaudio, #battery, #tray {
    padding: 0 12px;
    color: ${KAADZ_FG_ALT};
}
#clock { color: ${KAADZ_FG}; font-weight: 600; }
#battery.warning { color: ${KAADZ_WARNING}; }
#battery.critical { color: ${KAADZ_URGENT}; }
#network.disconnected { color: ${KAADZ_FG_MUTED}; }
WCSS

# ------------------------------------------------------------------------ foot
cat > "$cfg/foot/foot.ini" <<FOOT
[main]
font=${KAADZ_FONT_MONO}:size=${KAADZ_FONT_SIZE_TERM}
pad=12x10

[colors]
alpha=1.0
foreground=$(strip "$KAADZ_FG")
background=$(strip "$KAADZ_BG")
regular0=$(strip "$KAADZ_BORDER")
regular1=$(strip "$KAADZ_RED")
regular2=$(strip "$KAADZ_GREEN")
regular3=$(strip "$KAADZ_YELLOW")
regular4=$(strip "$KAADZ_ACCENT")
regular5=$(strip "$KAADZ_PURPLE")
regular6=$(strip "$KAADZ_TEAL")
regular7=$(strip "$KAADZ_FG_ALT")
bright0=$(strip "$KAADZ_FG_MUTED")
bright1=$(strip "$KAADZ_ORANGE")
bright2=$(strip "$KAADZ_GREEN")
bright3=$(strip "$KAADZ_WARNING")
bright4=$(strip "$KAADZ_SKY")
bright5=$(strip "$KAADZ_PINK")
bright6=$(strip "$KAADZ_TEAL")
bright7=$(strip "$KAADZ_FG")

[cursor]
style=beam
blink=yes
FOOT

# ---------------------------------------------------------------------- fuzzel
cat > "$cfg/fuzzel/fuzzel.ini" <<FUZ
[main]
font=${KAADZ_FONT_UI}:size=${KAADZ_FONT_SIZE}
lines=10
width=44
pad=16x14
icon-theme=Adwaita
[colors]
background=$(strip "$KAADZ_SURFACE")ee
text=$(strip "$KAADZ_FG")ff
prompt=$(strip "$KAADZ_ACCENT")ff
placeholder=$(strip "$KAADZ_FG_MUTED")ff
input=$(strip "$KAADZ_FG")ff
match=$(strip "$KAADZ_ACCENT")ff
selection=$(strip "$KAADZ_OVERLAY")ee
selection-text=$(strip "$KAADZ_FG")ff
selection-match=$(strip "$KAADZ_ACCENT")ff
border=$(strip "$KAADZ_BORDER")ff
[border]
width=2
radius=10
FUZ

# ----------------------------------------------------------------------- mako
cat > "$cfg/mako/config" <<MAKO
# KaadzOS notifications (generated from theme/palette).
font=${KAADZ_FONT_UI} ${KAADZ_FONT_SIZE}
background-color=${KAADZ_SURFACE}
text-color=${KAADZ_FG}
border-color=${KAADZ_ACCENT}
progress-color=over ${KAADZ_ACCENT}
border-size=2
border-radius=10
padding=12
margin=8
width=340
height=110
icons=1
max-visible=5
default-timeout=6000
[urgency=low]
border-color=${KAADZ_BORDER}
[urgency=high]
border-color=${KAADZ_URGENT}
default-timeout=0
MAKO

# ------------------------------------------------------------------- swaylock
cat > "$cfg/swaylock/config" <<LOCK
# KaadzOS lock screen (generated from theme/palette).
daemonize
show-failed-attempts
ignore-empty-password
image=${wall_guest}/wallpaper.png
scaling=fill
color=$(strip "$KAADZ_BG")
inside-color=$(strip "$KAADZ_SURFACE")cc
ring-color=$(strip "$KAADZ_BORDER")
key-hl-color=$(strip "$KAADZ_ACCENT")
bs-hl-color=$(strip "$KAADZ_URGENT")
text-color=$(strip "$KAADZ_FG")
inside-clear-color=$(strip "$KAADZ_BG_ALT")cc
inside-ver-color=$(strip "$KAADZ_BG_ALT")cc
inside-wrong-color=$(strip "$KAADZ_URGENT")cc
ring-clear-color=$(strip "$KAADZ_INFO")
ring-ver-color=$(strip "$KAADZ_ACCENT")
ring-wrong-color=$(strip "$KAADZ_URGENT")
text-ver-color=$(strip "$KAADZ_FG")
text-clear-color=$(strip "$KAADZ_FG")
text-wrong-color=$(strip "$KAADZ_URGENT_FG")
LOCK

# ----------------------------------------------------------------------- GTK
for ver in 3.0 4.0; do
cat > "$sys/gtk-$ver/settings.ini" <<GTK
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-font-name=${KAADZ_FONT_UI} ${KAADZ_FONT_SIZE}
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=menu
GTK
done

# ---------------------------------------------------------------------- Qt6ct
cat > "$cfg/qt6ct/qt6ct.conf" <<QTC
[Appearance]
color_scheme_path=/etc/qt6ct/colors/KaadzNight.conf
standard_dialogs=gtk3
icon_theme=Adwaita
style=Fusion

[Fonts]
font="${KAADZ_FONT_UI},${KAADZ_FONT_SIZE},-1,0,50,0,0,0,0,0"
fixed="${KAADZ_FONT_MONO},${KAADZ_FONT_SIZE_TERM},-1,0,50,0,0,0,0,0"
QTC

cat > "$sys/qt6ct/colors/KaadzNight.conf" <<QSC
[ColorScheme]
active_colors=#${KAADZ_FG#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_SURFACE#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG#\#}, #${KAADZ_FG#\#}, #${KAADZ_FG#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_BG#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_ACCENT#\#}, #${KAADZ_URGENT_FG#\#}, #${KAADZ_ACCENT#\#}, #${KAADZ_URGENT#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BG#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG#\#}, #${KAADZ_ACCENT_ALT#\#}
disabled_colors=#${KAADZ_FG_MUTED#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_SURFACE#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_BG#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BG#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_BORDER#\#}
inactive_colors=#${KAADZ_FG_ALT#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_SURFACE#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_BG#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_ACCENT#\#}, #${KAADZ_URGENT_FG#\#}, #${KAADZ_ACCENT#\#}, #${KAADZ_URGENT#\#}, #${KAADZ_BORDER#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BG_ALT#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_BG#\#}, #${KAADZ_FG_MUTED#\#}, #${KAADZ_FG_ALT#\#}, #${KAADZ_ACCENT_ALT#\#}
QSC

# ------------------------------------------------------------- virtual console
# A 16-colour palette for the Linux virtual terminals, applied by setvtrgb.
# setvtrgb expects three lines (red, green, blue) of 16 comma-separated values.
hex2rgb() { printf '%d %d %d' "$((16#${1:1:2}))" "$((16#${1:3:2}))" "$((16#${1:5:2}))"; }
{
  for channel in 1 2 3; do
    line=
    for hex in "$KAADZ_BG" "$KAADZ_RED" "$KAADZ_GREEN" "$KAADZ_YELLOW" \
               "$KAADZ_ACCENT" "$KAADZ_PURPLE" "$KAADZ_TEAL" "$KAADZ_FG" \
               "$KAADZ_FG_MUTED" "$KAADZ_ORANGE" "$KAADZ_GREEN" "$KAADZ_WARNING" \
               "$KAADZ_SKY" "$KAADZ_PINK" "$KAADZ_TEAL" "$KAADZ_FG"; do
      line="${line:+$line,}$(hex2rgb "$hex" | cut -d' ' -f"$channel")"
    done
    printf '%s\n' "$line"
  done
} > "$sys/vtrgb"

cat > "$sys/systemd/system/kaadzos-console-colors.service" <<'SVC'
[Unit]
Description=Apply the KaadzOS virtual-console palette
DefaultDependencies=no
After=systemd-vconsole-setup.service
Before=getty.target
ConditionPathExists=/dev/tty0

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/setvtrgb /etc/vtrgb

[Install]
WantedBy=sysinit.target
SVC

echo "KaadzOS theme configs generated into config/includes.chroot."

# ------------------------------------------------------ optional PNG wallpaper
# swaybg renders SVG only if an SVG loader is present; a committed PNG is the
# reliable fallback. Generate one here when Python is available.
if command -v python3 >/dev/null 2>&1; then
python3 - "$wall_dir/wallpaper.png" <<PY
import struct, zlib, sys
W,H=1920,1080
def h2r(x): x=x.lstrip('#'); return tuple(int(x[i:i+2],16) for i in (0,2,4))
top=h2r('$KAADZ_BG_ALT'); bot=h2r('$KAADZ_BG')
acc=h2r('$KAADZ_ACCENT'); pur=h2r('$KAADZ_PURPLE')
rows=bytearray()
cx,cy=W*0.72,H*0.28
for y in range(H):
    rows.append(0)
    t=y/(H-1)
    br=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3))
    for x in range(W):
        d=((x-cx)**2+(y-cy)**2)**0.5
        g=max(0.0,1.0-d/(W*0.9))
        r=min(255,int(br[0]+(acc[0]-br[0])*g*0.35))
        gch=min(255,int(br[1]+(acc[1]-br[1])*g*0.35))
        b=min(255,int(br[2]+(acc[2]-br[2])*g*0.35))
        rows+=bytes((r,gch,b))
def chunk(t,d):
    c=t+d; return struct.pack('>I',len(d))+c+struct.pack('>I',zlib.crc32(c)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'
png+=chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))
png+=chunk(b'IDAT',zlib.compress(bytes(rows),6))
png+=chunk(b'IEND',b'')
open(sys.argv[1],'wb').write(png)
print('wallpaper.png written')
PY
else
echo "python3 not found; skipped wallpaper.png (SVG still present)."
fi
