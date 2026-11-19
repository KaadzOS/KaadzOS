# KaadzOS daily-driver implementation plan

Status: living implementation plan for
[`daily-driver-roadmap.md`](daily-driver-roadmap.md). Prompt 1 recorded the
verified state below; the prompt sections are updated as each feature lands.
Prompts 2 (core baseline) and 3 (Bluetooth and Waybar) are implemented and
green in CI runs 44217239776 and 44250067376. Prompt 4 (Waybar control centre)
landed locally as `8cb8263`. The portal/session foundation, Prompt 5 (settings)
and Prompt 6 (greeter) are implemented locally in `e8ae260`, `e98f10a` and
`db477bb`. Prompt 7 (search) is implemented locally in `cdc7019` and `64c8b7f`.
Prompt 9 (GUI package management) is implemented locally in `39d30a4` and
`5c57729`; these changes await the next CI run.

Prepared: 2026-11-18, against `main` at `026091c`. Prompt 2 landed as `7a4e6e2`
and Prompt 3 as `a316fd1` plus the diagnostic fix `1b26d0d`.

## 1. Inputs inspected

- `README.md`, `AGENTS.md`, `docs/daily-driver-roadmap.md`
- `config/package-lists/base.list.chroot`
- `theme/palette` and `theme/generate.sh` (the source of the generated Sway,
  Waybar, foot, fuzzel, mako, swaylock, GTK, Qt6ct, Plymouth and Calamares
  files; the skel copies are committed build output)
- `config/includes.chroot/etc/skel/.config/{sway,waybar,foot,fuzzel,mako,swaylock}/`
- `config/includes.chroot/usr/local/bin/kaadzos` and the `kaadzos-*` helpers
- `config/includes.chroot/etc/calamares/` plus `kaadzos-install-finalize`
- `packs/*.pack`, `packs/hooks/`, `ci/test-packs.sh`
- `ci/test-boot.sh`, `ci/test-install.sh`, `.github/workflows/build.yml`

## 2. Current state

Already present and green before this roadmap:

- Base desktop: kernel, firmware, NetworkManager, Sway, Waybar, foot, fuzzel,
  mako, swaylock, swayidle, pipewire audio, pavucontrol, GTK/Qt theming.
- Lean defaults: Epiphany, Thunar, Mousepad, imv, zathura, recordings and
  screenshots.
- Installer: Calamares, greetd + tuigreet, first-boot cleanup, signed GRUB/shim.
- Packs: eight declarative packs, a POSIX-sh manager, add-ons UI.
- CI: `build` and `pack-test` both run `apt-cache show` over every base-list
  entry; `pack-test` resolves all packs; `repo-test`; BIOS/UEFI boot tests;
  BIOS/UEFI unattended install tests; tag-only `apt-repo` and `release`.

Prompt 2 has already started: `cb75a6a` added the explicit CLI baseline to the
base list, documented it in README, and added a guest-side command assertion.
That assertion failed all four boot/install jobs because `fdisk` was never
listed and `fsck`/`mkfs.ext4` were looked up on a desktop PATH without
`/usr/sbin`. `026091c` adds the `fdisk` package and widens only the lookup
PATH; CI run `44213408283` is the gate for that fix.

Gaps this plan closes:

- `xdg-desktop-portal*` was missing: the failed install logs showed
  `org.freedesktop.portal.Desktop was not provided by any .service files`, so
  file pickers, screen sharing and some GTK integrations degraded. Closed by
  the portal/session foundation below.
- Bluetooth, the control centre and the settings application were missing;
  all three are now implemented. A search helper, GUI package management,
  dock and context-menu helpers remain missing.
- Waybar originally had workspaces/clock/network/audio/battery/tray only;
  Bluetooth, backlight, power profile, idle inhibitor and the control centre
  have since landed.
- Printing, scanning, firmware/disk tools, VPN/firewall, Noto fonts, input
  methods and OpenCode are not represented as packs.

## 3. Package verification

Method: downloaded
`https://deb.debian.org/debian/dists/trixie/main/binary-amd64/Packages.xz`
(9,678,380 bytes) on 2026-11-18 and parsed every `Package:` stanza. Binary
locations were confirmed by unpacking the relevant `.deb` files. Re-run the
same check before adding a package in a later step; trixie point releases move
versions but the names below are the current suite contents.

Findings that change names in the roadmap draft:

| Roadmap name | Verified result | Decision |
|---|---|---|
| `p7zip-full` | transitional `16.02+transitional.1`, pulls `7zip`; `7zip` 25.01 installs `/usr/bin/7z` | list `7zip`, not the transitional name |
| `fwupd-signed` | not a package; `fwupd-amd64-signed` `1:1.7+1` **Provides** it | use `fwupd-amd64-signed` |
| `fcitx5-gtk` | not a package; split into `fcitx5-frontend-gtk3`, `-gtk4`, `-qt5`, `-qt6` | use the split names |
| `fcitx5-configtool` | not a package; the config GUI is `fcitx5-config-qt` | use `fcitx5-config-qt` |
| `nwg-dock`, `nwg-panel`, `sfwbar` | absent from trixie | no dock package; keep Waybar |
| `swaync`, `satty`, `apper`, `regreet` | absent from trixie | use mako, swappy/grim, apt tooling, tuigreet |
| `nwg-displays` / `wdisplays` | both present (`0.3.20-2` / `1.1.1-1+b2`) | `nwg-displays`, with `wlr-randr` as CLI fallback |
| GTK greeters | `nwg-hello 0.3.0-1` and `gtkgreet 0.8-1+b1` exist | both are layer-shell greeters that need a compositor wrapper; not a drop-in tuigreet replacement |

Verified candidates (version — installed size):

**Core / baseline** — `bash 5.2.37`, `dash 0.5.12`, `zsh 5.9`, `coreutils 9.7`,
`util-linux 2.41.5`, `fdisk 2.41.5` (separate package), `findutils 4.10`,
`grep 3.11`, `gawk 5.2.1`, `tar 1.35`, `gzip 1.13`, `xz-utils 5.8.1`,
`zstd 5.7`, `e2fsprogs 1.47.2`, `7zip 25.01`, `unzip 6.0`, `zip 3.0`,
`rsync 3.4.1`, `less 668`, `man-db 2.13.1`, `manpages 6.9.1`, `file 5.46`,
`tree 2.2.1`, `pciutils 3.13`, `usbutils 018`, `procps 4.0.4`, `lsof 4.99.4`,
`htop 3.4.1` (~15 MB total).

**Portal / session integration** — `xdg-desktop-portal 1.20.3` (2.2 MB),
`xdg-desktop-portal-gtk 1.15.3` (0.7 MB), `xdg-desktop-portal-wlr 0.7.1`
(0.1 MB). Base: required for file pickers and screen sharing.

**Filesystem integration** — `udisks2 2.10.1` (2.8 MB), `udisks2-btrfs 2.10.1`,
`gvfs 1.57.2`, `gvfs-backends 1.57.2`, `gvfs-fuse 1.57.2`,
`thunar-volman 4.20.0`, `tumbler 4.20.0`. Base: Thunar volume and thumbnail
integration currently has no udisks/gvfs backend even though recommends are off.

**Bluetooth** — `bluez 5.82` (4.8 MB), `blueman 2.4.4` (4.2 MB), optional
`bluez-tools 2.0`. Base for Prompt 3; Blueman is the only complete GTK
frontend in trixie and uses the already-present `python3`.

**Power / display / night light** — `upower 1.90.9` (0.3 MB),
`power-profiles-daemon 0.30` (0.2 MB), `wlsunset 0.3.0` (45 KB),
`gammastep 2.0.9` (0.8 MB), `wlr-randr 0.4.1` (44 KB),
`nwg-displays 0.3.20` (0.1 MB), `wdisplays 1.1.1` (0.2 MB). Base: upower,
power-profiles-daemon, wlsunset and wlr-randr; hardware pack: nwg-displays.

**Dialogs / clipboard / archives** — `zenity 4.1.90` (0.2 MB, GTK4),
`yad 0.40.0`, `wl-clipboard 2.2.1` (0.2 MB), `cliphist 0.5.0`,
`thunar-archive-plugin 0.5.3` (0.4 MB), `xarchiver 0.5.4` (1.7 MB),
`file-roller 44.5` (4.9 MB). Base: zenity, wl-clipboard,
thunar-archive-plugin + xarchiver. `cliphist` is optional; add later if a
clipboard history is wanted.

**Printing / scanning pack** — `cups 2.4.10`, `cups-client 2.4.10`,
`cups-filters 1.28.17`, `cups-pk-helper 0.2.6`, `system-config-printer 1.5.18`,
`printer-driver-all 0.20210903`, `cups-browsed 1.28.17`, `avahi-daemon 0.8`,
`libnss-mdns 0.15.1`, `sane-utils 1.3.1`, `sane-airscan 0.99.35`,
`simple-scan 46.0` (6.0 MB). All present.

**Hardware / admin pack** — `fwupd 2.0.20` (11.6 MB),
`fwupd-amd64-signed 1.7`, `gnome-firmware 47.0`, `gnome-disk-utility 46.1`
(7.1 MB), `gparted 1.6.0` (2.2 MB), `smartmontools 7.4`, `nvme-cli 2.13`,
`lm-sensors 3.6.2`, `gsmartcontrol 2.0.2`, `testdisk 7.2`, `ntfs-3g 2022.10.3`,
`exfatprogs 1.2.9`, `btrfs-progs 6.14`, `xfsprogs 6.13`, `inxi 3.3.38`,
`hardinfo 2.2.10`. All present. Keep the heavy GUI tools optional.

**Network pack** — `network-manager-openvpn 1.12.3`,
`network-manager-openvpn-gnome 1.12.3`, `network-manager-openconnect 1.2.10`,
`network-manager-openconnect-gnome 1.2.10`, `wireguard-tools 1.0.20210914`,
`nm-connection-editor 1.36.0` (5.3 MB), `network-manager-gnome 1.36.0`.
All present.

**Security pack** — `ufw 0.36.2`, `gufw 24.04.0` (3.7 MB), `nftables 1.1.3`,
`firewalld 2.3.1` (alternative). Choose ufw + gufw; never enable by default.

**Fonts pack** — `fonts-noto-core 20201225` (42.6 MB),
`fonts-noto-color-emoji 2.051` (11.0 MB), `fonts-noto-mono` (1.2 MB),
`fonts-noto-cjk` (91 MB, optional), `fonts-noto-extra` (334 MB, optional).
All present; keep the large faces out of base.

**Input pack** — `fcitx5 5.1.12`, `fcitx5-frontend-gtk3/gtk4/qt5/qt6`,
`fcitx5-config-qt 5.1.8`, `fcitx5-chinese-addons`, `fcitx5-pinyin`,
`fcitx5-hangul`, `fcitx5-unikey`, `fcitx5-anthy`, `fcitx5-mozc`. All present.

**Package management** — `synaptic 0.91.7` (7.8 MB; apt directly, Xwayland
already present), `aptitude 0.8.13`, `gnome-software 48.3` (PackageKit; excluded
by the roadmap's "apt only" rule). Base already has `zenity` after this plan.

**Add-ons with no trixie package** — OpenCode itself (pack fetches a pinned
upstream binary in the style of `cloudflare.pack`), and `nwg-dock` for Prompt 8.

## 4. Dependency-ordered plan

Ordering rule: every step keeps the existing gates green, adds its own
assertions, and does not depend on a later step. Prompts 9–12 are independent
of each other once 5 lands; Prompt 13 closes over everything and Prompt 14
ships the story.

```
2 (baseline)
   -> 3 (Bluetooth) -> 4 (control centre) -> 5 (settings)
        -> 6 (greeter)        [UI/theme review, no new feature dependency]
        -> 7 (search)
        -> 9 (package GUI)    [uses kaadzos + launchers]
        -> 10 (hardware/network packs) [uses settings/control entry points]
             -> 11 (context actions)
        -> 12 (OpenCode pack) [independent after 2; do after security review]
   8 (dock) is a documented no-op because trixie has no Wayland dock package.
   13 (validation sweep) and 14 (docs/release) run last.
```

### Prompt 2 — Core baseline (finish)

Status: complete. CI run [44217239776](https://github.com/KaadzOS/KaadzOS/actions/runs/44217239776)
(commit `7a4e6e2`) passed `pack-test`, `repo-test`, `build`, `boot-test`
(bios/uefi) and `install-test` (bios/uefi).

Depends on: nothing. Most of this landed in `cb75a6a`; `026091c` fixes the
command assertion.

- Base list: add `fdisk` (done), replace the `p7zip-full` transitional with
  `7zip`, keep `apt-recommends=false`. `e2fsprogs`, `util-linux` and `zstd`
  are already present.
- README: change the baseline sentence to name `7zip` and the disk tools.
- CI: factor the two duplicated `apt-cache show` loops into
  `ci/test-base-list.sh` and call it from `build` and `pack-test`; keep the
  guest assertion in `kaadzos-session-ready` as the runtime check.
- Files: `config/package-lists/base.list.chroot`, `README.md`,
  `ci/test-base-list.sh` (new), `.github/workflows/build.yml`.
- Exit: boot and install jobs emit `KAADZOS_COMMANDS_OK` on both firmwares.

### Prompt 3 — Bluetooth and Waybar

Status: complete. CI run [44250067376](https://github.com/KaadzOS/KaadzOS/actions/runs/44250067376)
(commit `1b26d0d`) passed `pack-test`, `repo-test`, `build`, `boot-test`
(bios/uefi) and `install-test` (bios/uefi). The first run (44230914684) exposed
a `bluetoothctl` hang in the session diagnostic when no adapter is present;
`1b26d0d` bounds every probe with `timeout` and adds a static regression check.

Package: `bluez`, `blueman`, `dconf-gsettings-backend`, `libglib2.0-bin`.
`bluez-tools` is not needed: `bluetoothctl` ships in `bluez`, and Blueman is
the manager.

Depends on: 2.

- Enable `bluetooth.service` from a live hook; the service must stay green
  with no adapter (`ConditionPathIsDirectory=/sys/class/bluetooth`).
- Add a Waybar `bluetooth` module with icons for off/unavailable/powered/
  connected/scanning, device name in the tooltip, left-click opens
  `blueman-manager`, right-click toggles `bluetoothctl power on|off`.
- Add a control-centre entry and a Sway binding (`$mod+x` is free). The
  control-centre entry itself lands with Prompt 4; Prompt 3 ships the shared
  `kaadzos-bluetooth` helper it will call.
- Files: `theme/generate.sh` (Waybar block, Sway bindings),
  `config/includes.chroot/etc/skel/.config/waybar/{config,style.css}`,
  `config/includes.chroot/etc/skel/.config/sway/config`,
  `config/includes.chroot/usr/local/bin/kaadzos-bluetooth` (new),
  `config/hooks/live/0800-bluetooth.hook.chroot` (new), base list,
  `ci/test-desktop.sh` (new).
- Tests: `ci/test-desktop.sh` parses the Waybar JSON, requires the module and
  its click actions, checks the state styling and the single `$mod+x` binding,
  runs `dash -n` on the helper and hook, and requires every `bluetoothctl`
  probe to be bounded with `timeout`. `kaadzos-session-ready` emits
  `KAADZOS_BLUETOOTH_OK`, `KAADZOS_BLUETOOTH_MODULE_OK` and
  `KAADZOS_WAYBAR_OK`; the live and installed boot tests fail on
  `KAADZOS_BLUETOOTH_FAILED`, `..._DISABLED`, `..._MODULE_MISSING` or
  `KAADZOS_WAYBAR_FAILED`, and still require no `swaynag` and a screenshot.
- Risk: Blueman pulls GTK/GSettings at runtime; with recommends off it needs
  `dconf-gsettings-backend` and `libglib2.0-bin` (confirmed and listed
  explicitly). `mako-notifier` Provides `notification-daemon`, so Blueman does
  not pull a second notification daemon.

### Prompt 4 — Waybar control centre

Status: landed locally as `8cb8263`; the next push must run the normal matrix
before this is recorded as green. The helper is `dash`-clean and the action
dispatch is covered by fake-command tests that run in both the `build` and
`pack-test` containers (`ci/test-control.sh`).

Depends on: 3 (Bluetooth toggle), 2 (`zenity`).

- `kaadzos-control`: fuzzel/zenity menu over audio + mic (`wpctl`), Bluetooth
  (`bluetoothctl`, Blueman), network (`nmcli`; `nm-connection-editor` when the
  network pack is installed), brightness (`brightnessctl`), battery/power
  profile (`upower`, `powerprofilesctl`), night light (`wlsunset`), screenshot/
  recording (`kaadzos-screenshot`, `kaadzos-record`), power actions.
- Waybar: add `backlight`, `power-profiles-daemon`, `idle_inhibitor`, and
  `custom/control`; make battery click open the power section; network click
  fall back from `nm-connection-editor` to the control centre.
- Base additions: `upower`, `power-profiles-daemon`, `wlsunset`, `zenity`.
  `wlsunset` needs the Sway gamma-control protocol; hide the item if the
  command or protocol is unavailable.
- Files: `config/includes.chroot/usr/local/bin/kaadzos-control` (new),
  `theme/generate.sh` + generated Waybar/Sway files,
  `config/includes.chroot/usr/share/applications/kaadzos-control.desktop`,
  base list.
- Tests: launcher exists; `kaadzos-control` parses under `dash -n`; guest
  emits `KAADZOS_CONTROL_OK`; no swaynag.
- Risk: `wpctl`, `nmcli`, `bluetoothctl`, `brightnessctl` and
  `powerprofilesctl` must all be present or the menu must hide the item; test
  each absence path.

### Portal and session integration (foundation)

Status: implemented locally on 2026-11-18 (`e8ae260`); CI validation is
pending the next push. This is the shared dependency for file pickers, screen
sharing and the GTK integrations used by Settings and the file manager.

Depends on: 2 (`dbus`, `libglib2.0-bin`).

- Base: `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-wlr`.
  The GTK backend serves the general desktop interfaces; the wlroots backend
  serves `ScreenCast` and `Screenshot` on Sway.
- Backend selection: `/etc/xdg/xdg-desktop-portal/portals.conf` sets
  `default=gtk`, `org.freedesktop.impl.portal.ScreenCast=wlr` and
  `org.freedesktop.impl.portal.Screenshot=wlr`.
- Session environment: the generated Sway config calls
  `dbus-update-activation-environment` for the private `dbus-run-session` bus
  and, with `--systemd`, for the systemd user manager. Both calls carry
  `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=sway`, `XDG_SESSION_TYPE`,
  `XDG_SESSION_DESKTOP` and `XDG_RUNTIME_DIR`; the systemd call is bounded so a
  missing user manager cannot hold the session open.
- Tests: `ci/test-desktop.sh` checks the packages, the Sway wiring and the
  backend config. `kaadzos-session-ready` activates
  `org.freedesktop.portal.Desktop` with a bounded `gdbus` Ping and emits
  `KAADZOS_PORTAL_OK`; the live and installed boot gates require it and fail on
  `KAADZOS_PORTAL_FAILED`.
- Risk: the portal is D-Bus activated, so updating only the systemd user
  environment is not enough under `dbus-run-session`; the bus update is the
  functional one. The wlroots ScreenCast chooser still needs a manual
  multi-output/region test because the CI VM cannot exercise it.

### Prompt 5 — Themed settings application

Status: implemented locally on 2026-11-19 in `5a64c6c` (config.d include),
`095fb93` (`kaadzos-file-action`), `e98f10a` (`kaadzos-settings`) and
`6ec3073` (session gate); the next push must run the normal matrix before this
is recorded as green. The helper is `dash`-clean and the actions are covered by
fake-command tests in `ci/test-file-actions.sh` and `ci/test-settings.sh`,
which run in both container jobs.

Depends on: 3, 4 (shared actions), 10 for display/network editors (optional
items degrade gracefully).

- No suitable full settings application exists in trixie. `gnome-control-center`
  is GNOME-coupled and heavy; `lxqt-config` is Qt/X11-leaning. Use a small
  `kaadzos-settings` (POSIX sh + zenity) with sections: Appearance (wallpaper,
  night light, GTK font/icon via `gsettings`), Input (keyboard layout, tap),
  Display (`nwg-displays` when installed, else `wlr-randr` text), Network
  (`nm-connection-editor` when installed, else `nmcli` text), Bluetooth
  (`blueman-manager`), Sound (`pavucontrol`), Power, Default apps
  (`xdg-settings`), About.
- Persist session config in `~/.config/kaadzos/settings.conf` and user Sway
  overrides in `~/.config/sway/config.d/`; never edit generated theme files.
  The generated Sway config needs `include ~/.config/sway/config.d/*.conf`
  for this; the README and the default `.conf` file keep the glob inert and
  always matching.
- Files: `kaadzos-settings` (new), `kaadzos-file-action` (new, shared with 11;
  this iteration implements the safe `wallpaper` action and rejects control
  characters and leading dashes), `theme/generate.sh` + generated Sway config,
  skel `config.d/{README,00-default.conf}`, desktop entry, `$mod+comma`
  binding.
- Tests: `dash -n`; launcher; `ci/test-file-actions.sh` covers spaces, quotes,
  Unicode, symlinks, newlines and leading dashes; `ci/test-settings.sh`
  exercises every section with fake commands; `kaadzos-session-ready` emits
  `KAADZOS_SETTINGS_OK` and the live/installed gates require it. Missing
  optional commands leave one section disabled, not broken.
- Risk: `gsettings` needs `libglib2.0-bin` and a GSettings backend; `pkexec`
  strips the Wayland environment, so privileged actions must pass
  `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR` and `XDG_SESSION_TYPE` explicitly.

### Prompt 6 — Display-manager theming

Status: implemented locally on 2026-11-19 as `db477bb`; the next push must run
the full matrix before this is recorded as green. The static checks run in both
container jobs, and `install-test` now requires `KAADZOS_GREETER_OK`.

Depends on: 5 (settings entry points).

- Keep greetd + tuigreet. `nwg-hello` and `gtkgreet` are layer-shell greeters
  that need a compositor started by greetd; adopting either is a compositor
  integration project, not a theme swap. Document that decision.
- Strengthen the installed tuigreet: keep the white/grey `--theme` written by
  `kaadzos-install-finalize`, pin VT 7, add the `KaadzOS` greeting and the
  Waybar clock format, and verify the VT/plymouth hand-off still has no race.
  tuigreet renders in the Linux VT font, so Inter Tight is not applicable; a
  proportional font would need a compositor greeter.
- Files: `config/includes.chroot/etc/calamares/modules/displaymanager.conf`,
  `config/includes.chroot/usr/local/bin/kaadzos-install-finalize`,
  `config/includes.chroot/usr/share/plymouth/themes/kaadzos` (generated),
  `ci/test-install.sh`.
- Tests: `ci/test-greeter.sh` checks the theme tokens, greeting, time format,
  VT 7, the `_greetd` identity and the Plymouth ordering. Installed BIOS/UEFI
  boot reaches greetd, logs in, reaches `KAADZOS_SWAY_READY`, and
  `kaadzos-session-ready` emits `KAADZOS_GREETER_OK` for the install gate.
- Risk: changing the greeter command can lock the installed image out of a
  session; keep the CI driver's existing `tuigreet` login path and add a
  fallback assertion.

### Prompt 7 — Spotlight-style search

Depends on: 5 (settings/pack entries).

- `kaadzos-search`: build one candidate list (desktop entries, recent XBEL
  entries, bounded `find` over `$HOME`, settings pages, `kaadzos list`, static
  command map), pipe it to `fuzzel --dmenu`, then dispatch the selection.
  Keep plain app launcher on `$mod+Shift+d`; `$mod+d` becomes smart search.
- Exclusions: `~/.ssh`, `~/.gnupg`, `~/.local/share/keyrings`, browser profile
  dirs, trash, caches, `node_modules`, `.git`; bound depth and time; drop NUL/
  newline names from the dmenu list (fuzzel is line-oriented).
- Files: `kaadzos-search` (new), `theme/generate.sh` + generated Sway config
  and fuzzel prompt, `ci/test-search.sh` (new).
- Tests: paths with spaces and Unicode; no results; missing recent file;
  excluded directories; `dash -n`; no shell evaluation of filenames.
- Risk: `find $HOME` latency on large homes; cap it and prefer recent files.

Status: implemented locally on 2026-11-19 in `cdc7019` (helper and
`ci/test-search.sh`) and `64c8b7f` (the `$mod+d`/`$mod+Shift+d` split, desktop
checks and both container job calls); CI validation is pending the next push.

The helper reads recent entries from `$XDG_DATA_HOME/recently-used.xbel`,
prefers them over the depth-6 `timeout 2 find` scan and caps both at 100
recent entries and 200 home files. It emits TAB-separated kind/label/value
records, prunes the sensitive and noisy directories listed above, drops
control-character and newline names, refuses leading-dash values and passes
the selected value as argv to `gio launch`, `xdg-open`, `kaadzos-settings`,
`kaadzos add` in foot or a fixed command. `ci/test-search.sh` covers candidate
generation, spaces, Unicode, recent decoding and removal, exclusions,
newline-name rejection, every dispatch path, cancellation, unknown kinds and
the no-`eval` rule.

### Prompt 8 — Wayland dock

Decision: no implementation now. `nwg-dock`, `nwg-panel`, `sfwbar` and other
Wayland docks are not in trixie. Do not add an X11 dock and do not vendor a Go
binary into the base. Keep Waybar as the supported bar; revisit only if a
trixie package appears. Record the decision in README/docs (Prompt 14).

Status: decision recorded locally on 2026-11-19. No package or binary was
added; the user-facing README note remains part of the Prompt 14 pass.

### Prompt 9 — GUI package management

Depends on: 2 (`kaadzos`), 5 (launcher patterns).

- Use apt directly, no PackageKit. `synaptic` covers search, installed view,
  install/remove, refresh and progress; add a small `kaadzos-packages` zenity
  front page that also lists packs (`kaadzos list`) and explains the optional
  signed archive (`docs/apt-repository.md` excerpt).
- Authorization: polkit (`pkexec`) for privileged actions, explicit
  confirmation before remove; handle apt lock and offline states; never run
  `apt` from a filename or unquoted argument.
- Placement: `admin` pack (`synaptic`, `zenity` in base). Launcher in
  Waybar/Fuzzel and Settings.
- Files: `kaadzos-packages` (new), `packs/admin.pack` (new), desktop entry,
  `$mod+Shift+p`? (pick a free binding), `theme/generate.sh` Waybar button,
  `ci/test-packages.sh` (fake apt/PATH stub).
- Tests: fake apt backend for install/remove/refresh, lock error, offline
  error, destructive confirmation, pack listing.
- Risk: `synaptic` is X11; it runs under the already-present Xwayland. Test
  launch in the boot test (or assert its desktop entry and binary only if
  installing the pack in CI is affordable).

Status: implemented locally on 2026-11-19 in `39d30a4` (the `kaadzos-packages`
helper, `ci/test-packages.sh` and the `admin` pack) and `5c57729` (the desktop
entry, `$mod+Shift+p`, Waybar module, Settings row, search entry, generated
configs and CI calls); CI validation is pending the next push.

The base front end uses zenity for its menu and `kaadzos` for the pack list;
`admin` supplies `synaptic`, `pkexec` and `lxpolkit`, and the generated Sway
config starts `lxpolkit` only when it is installed. Privileged actions validate
the package name, pass it as one argv, confirm installs/removes (remove
defaults to cancel), and distinguish a locked dpkg from an unreachable archive.
The test stubs apt, pkexec, zenity, Synaptic and `kaadzos` to cover refresh,
install/remove confirmation, lock, offline, invalid names, packs, archive and
About without installing anything or showing a polkit prompt. The boot test
does not launch Synaptic because the admin pack is optional; the pack test
resolves its packages in trixie instead.

### Prompt 10 — Driver, firmware, disk, printer and network tools

Depends on: 4/5 (entry points).

- Add packs, not base payload:
  - `printing`: cups, cups-client, cups-filters, cups-pk-helper,
    system-config-printer, printer-driver-all, cups-browsed, avahi-daemon,
    libnss-mdns, sane-utils, sane-airscan, simple-scan. Hook enables
    `cups.service`/`avahi-daemon.service` and adds the user to `lp`/`scanner`
    only when the pack is installed.
  - `hardware`: fwupd, fwupd-amd64-signed, gnome-firmware, gnome-disk-utility,
    gparted, nwg-displays, smartmontools, nvme-cli, lm-sensors, gsmartcontrol,
    testdisk, ntfs-3g, exfatprogs, btrfs-progs, xfsprogs, inxi.
  - `network`: NetworkManager VPN/OpenConnect plugins, wireguard-tools,
    nm-connection-editor, network-manager-gnome.
- No boot dependency on hardware. Destructive actions (format, firmware
  update, firewall enable) require explicit confirmation and a polkit prompt.
- Files: `packs/{printing,hardware,network}.pack` (new),
  `packs/hooks/{printing,hardware,network}.sh` (new),
  `kaadzos-control`/`kaadzos-settings` optional entries, README pack table.
- Tests: pack resolution (existing `test-packs.sh` picks up every `.pack`);
  hook `dash -n`; dry-run on a trixie container. Keep full installs out of CI
  to protect the 40/90-minute budgets; smoke-test the services only if a
  pack can be installed inside the existing install job.
- Risk: firmware updates must never run unattended in CI; CUPS/avahi open
  network listeners, so they stay in a pack and off by default.

### Prompt 11 — Safe context-menu actions

Depends on: 5 (`kaadzos-file-action`), 10 (archive tools in a pack or base).

- Thunar custom actions in skel `uca.xml`, each calling a single helper:
  terminal here (`foot --working-directory`), copy path (wl-copy +
  notify-send), compress/extract (thunar-archive-plugin + xarchiver),
  set wallpaper (write `~/.config/sway/config.d/10-wallpaper` + `swaymsg`),
  open settings, install local package (explicit zenity confirmation, then
  `pkexec apt install ./file.deb`).
- No action may eval or concatenate the filename into a shell string. Thunar
  does not quote `%f`; the helper must receive the path as an argument and
  refuse paths containing newlines, NUL, `$`, backticks or leading `-`.
- Files: `config/includes.chroot/etc/skel/.config/Thunar/uca.xml` (new),
  `kaadzos-file-action` (new), base additions `thunar-archive-plugin`,
  `xarchiver`, `wl-clipboard`, `ci/test-file-actions.sh` (new).
- Tests: spaces, quotes, Unicode, symlinks, `-rf`, newline rejection,
  no-argument and missing-file errors.
- Risk: "open as administrator" is the hardest case; prefer Thunar's
  `admin://` location with gvfs + polkit over launching a root file manager.

### Prompt 12 — OpenCode optional pack

Depends on: 2 (pack system), security review. Not in base.

- `packs/opencode.pack` with a hook that downloads a pinned,
  architecture-matched upstream binary over HTTPS, verifies a SHA-256, installs
  it under `/usr/local/bin/opencode`, and leaves no secrets in the image or
  artifacts. Mirror the `cloudflare.pack` static-binary pattern.
- Launcher: Fuzzel entry and Settings item with a first-run consent dialog that
  names the project directory and states that the agent can read/write there;
  no automatic sudo, no auto-start, no credential injection, no silent updates.
- Files: `packs/opencode.pack`, `packs/hooks/opencode.sh` (new),
  `config/includes.chroot/usr/share/applications/opencode.desktop` (new; only
  installed by the pack hook), `docs/opencode.md` (security notes),
  `ci/test-opencode.sh` (dry-run + checksum/URL validation with a local
  fixture).
- Tests: dry-run plans the download but does not execute it; secret scan over
  the pack/hook/artifacts; missing checksum fails; unsupported architecture
  fails cleanly.

### Prompt 13 — Complete validation and regression coverage

Depends on: all feature prompts. Additive only; never weaken a gate.

- `ci/test-base-list.sh`: the existing `apt-cache show` loop, called from both
  `build` and `pack-test`.
- `ci/test-helpers.sh`: `dash -n` and `shellcheck` for every new helper;
  functional tests for search, file actions, control centre absence paths,
  settings persistence, fake apt, OpenCode dry-run and secret scan.
- Guest assertions in `kaadzos-session-ready` (live and installed):
  `KAADZOS_COMMANDS_OK` (already), `KAADZOS_PORTAL_OK`, `KAADZOS_WAYBAR_OK`,
  `KAADZOS_BLUETOOTH_OK` (not failed), `KAADZOS_LAUNCHER_OK`.
- `ci/test-boot.sh` fails on the new markers; `ci/test-install.sh` repeats them
  after install and keeps the existing Calamares/sudoers/first-boot checks.
- Keep the two boot and two install QEMU runs; do not add a third firmware run.
- Files: `ci/test-*.sh`, `kaadzos-session-ready`, `.github/workflows/build.yml`,
  `README.md`.
- Risk: CI runtime growth; keep new checks in the existing container jobs and
  the existing two QEMU matrices.

### Prompt 14 — Documentation and release readiness

Depends on: 13 green.

- README: base features vs optional packs, hardware-dependent features, the
  dock decision, OpenCode security notes, updated package baseline.
- `site/docs/`: chapters for Bluetooth, control centre, settings, search,
  package management, packs, printing/scanning, hardware tools, VPN/firewall,
  fonts, input methods and OpenCode; keep the no-JavaScript reading path.
- `AGENTS.md`: decisions and phase record; `docs/release-notes/<tag>.md`;
  `docs/daily-driver-plan.md` marked done.
- Verify: every listed package resolved in trixie, no generated theme file
  hand-edited in a way `theme/generate.sh` would overwrite, no secrets or
  non-free runtime deps, licences recorded, `apt-recommends=false`, ISO size
  budget, and `sha256sum --check` on the release artifact.
- Exit: tag push runs the full matrix and the release publishes only a green
  image.

## 5. Base vs pack summary

| Change | Placement | Approx. installed |
|---|---|---|
| `fdisk`, `7zip` | base | 7.5 MB |
| portals (xdg-desktop-portal + GTK/WLR) | base | 3 MB |
| gvfs/udisks/Thunar integration | base (follow-up) | 5.5 MB |
| Bluetooth (bluez + blueman) | base | 9 MB |
| upower, power-profiles-daemon, wlsunset, wlr-randr, zenity, wl-clipboard | base | 1 MB |
| Thunar archive plugin + xarchiver | base | 2 MB |
| printing/scanning | `printing` pack | 30–60 MB |
| firmware/disk/display tools | `hardware` pack | 40–60 MB |
| VPN/OpenConnect/WireGuard | `network` pack | 20–40 MB |
| ufw + gufw | `security` pack | 10 MB |
| Noto core + emoji + mono | `fonts` pack | 55 MB |
| fcitx5 + frontends + config | `input` pack | 20 MB |
| synaptic + pack front page | `admin` pack | 10 MB |
| OpenCode | `opencode` pack | ~100 MB |
| dock | none (not packaged) | — |

Base growth is about 28 MB installed, or roughly 10–15 MB of ISO. That keeps
the ISO near 1.45 GB before packs.

## 6. Cross-cutting risks

- **Package drift**: verified against the 2026-11-18 trixie index; re-verify
  each name immediately before editing a list.
- **Minimal-image creep**: every base addition needs a boot, installer or
  session reason; heavy GUIs go to packs.
- **Service races and hardware absence**: Bluetooth, CUPS, Avahi and fwupd
  must be non-fatal without hardware and must never delay the session.
- **Portal/PipeWire environment**: the generated Sway config now updates both
  the private `dbus-run-session` bus and the systemd user manager with
  `WAYLAND_DISPLAY` and the desktop/session names, and the boot gates activate
  the portal bus. Keep this wiring in sync if the session wrapper changes.
- **Quoting and untrusted filenames**: all file actions go through one
  validating helper; no `eval`, no string-built shell commands.
- **Privilege boundaries**: `pkexec` strips the Wayland environment; pass the
  session variables explicitly and test the failure path.
- **CI runtime**: new tests stay in containers; QEMU matrices stay at 2×boot
  and 2×install.
- **Scope**: 14 prompts is a lot of surface; each prompt should land as its
  own green run, not a batch.

## 7. Open decisions for the owner

1. Bluetooth and power-profiles-daemon in base (recommended, ~9 MB) or in a
   `bluetooth`/`power` pack?
2. Keep tuigreet for Prompt 6 (recommended) or invest in a compositor wrapper
   for `nwg-hello`/`gtkgreet`?
3. No dock (recommended, trixie has no Wayland dock package) or vendor an
   upstream binary in an optional pack?
4. `fonts-noto-cjk` (91 MB) and `fonts-noto-extra` (334 MB) in the `fonts`
   pack, or keep the pack at core + emoji + mono?
5. OpenCode distribution: pinned GitHub release binary (recommended) versus
   upstream install script executed at pack-install time?
