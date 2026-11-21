# KaadzOS daily-driver roadmap

This document records the planned expansion of the minimal Sway desktop into a
daily-driver system. It is a planning document only; no implementation changes
are implied by its presence. The verified, dependency-ordered output of
Prompt 1 lives in [`daily-driver-plan.md`](daily-driver-plan.md), which carries
the live status. Prompts 2-13 and the portal/session foundation are green in
CI; Prompt 14 (documentation and release readiness) is complete with green
branch runs [44872951906](https://github.com/KaadzOS/KaadzOS/actions/runs/44872951906)
(full build matrix, commit `f85d1b5`) and
[44872660750](https://github.com/KaadzOS/KaadzOS/actions/runs/44872660750)
(site deploy, commit `ee5c40b`); the annotated `v0.4.0` tag points at
`cd0a7e9`, and tag run
[44881594815](https://github.com/KaadzOS/KaadzOS/actions/runs/44881594815)
published the release and APT archive. Prompt 8 keeps Waybar and declines a
Wayland dock.

## Principles

- Debian trixie, amd64 only.
- Sway on Wayland; no replacement compositor.
- live-build, `apt-recommends=false`.
- Base ISO stays minimal; heavy or optional features become packs.
- Every package must be verified with `apt-cache` in a trixie container before
  it is added to any list.
- Existing CI gates (pack-test, build, boot-test, install-test, apt-repo,
  release) must remain green; new checks are additive.

## Core system baseline (candidate list)

Verify each name in trixie before editing. Names marked `?` are known to need
confirmation.

```text
bash
dash
zsh
coreutils
util-linux
findutils
grep
gawk
tar
gzip
xz-utils
zstd
e2fsprogs

bluez
blueman
cups
cups-client
system-config-printer
fwupd
fwupd-signed ?
udisks2
udisks2-btrfs
gvfs
gvfs-backends
polkitd          # replaces policykit-1 if transitional/removed
p7zip            # verify p7zip-full vs 7zip in trixie
unzip
zip
rsync
less
man-db
manpages
file
tree
pciutils
usbutils
lsof
procps
htop
```

Also consider, mostly as optional or base-light additions:

- `network-manager-openvpn`
- `network-manager-openconnect`
- `wireguard-tools`
- `avahi-daemon`
- `sane-airscan`
- `simple-scan`
- `firewalld` or `ufw`
- `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-wlr`
- `fonts-noto-core`
- `fonts-noto-color-emoji`
- `fcitx5` plus an input-method pack
- `power-profiles-daemon`
- `upower`
- `nwg-displays` or an equivalent display tool (verify `wdisplays`)

## Base vs. pack split

Base ISO keeps only what boot, installer, or core session behavior needs.
Everything else becomes a pack:

| Feature | Placement |
|---|---|
| Core CLI baseline | base |
| Bluetooth (bluez + blueman) | base or `bluetooth` pack |
| Printing / scanning | `printing` pack |
| Firmware reporting (fwupd) | `hardware` pack |
| Disk / filesystem tools | `hardware` pack |
| VPN (openvpn/openconnect/wireguard) | `network` pack |
| Firewall | `security` pack |
| Display configuration | `hardware` pack |
| Power profiles | base or `power` pack |
| Archives / compression extras | base (already minimal) |
| Fonts (Noto, emoji) | `fonts` pack |
| Portal (xdg-desktop-portal + GTK/WLR backends) | base (implemented) |
| Input methods (fcitx5) | `input` pack |
| Dock | optional pack with Waybar fallback |
| GUI package manager | optional pack |
| OpenCode client | optional pack |
| Spotlight search | base (shell + fuzzel) |
| Settings application | base only if lightweight |
| Control centre | base only if lightweight |

## Feature roadmap

### 1. Establish desktop feature roadmap
Inspect README.md, AGENTS.md, base package list, Sway/Waybar configs, `kaadzos`,
CI scripts, and build workflow. Produce dependency-ordered plan with package
candidates, risks, and files to change. No edits in this step.

### 2. Core system baseline
Add explicit baseline packages to `config/package-lists/base.list.chroot`, keep
comments consistent, preserve `apt-recommends=false`, and update README.md.
Extend CI to check every listed package with `apt-cache` and verify key commands
in live and installed images.

### 3. Bluetooth and Waybar integration
Add BlueZ and the smallest suitable graphical frontend (Blueman if available).
Enable the service safely, keep boot non-fatal without hardware, and add a Waybar
Bluetooth module with disabled/unavailable/powered/connected/scanning states,
device-name display, manager launch, and safe power toggle. Add Sway shortcut,
package/shell tests, and boot-test non-fatal assertion.

### 4. Waybar control centre
Prefer an existing small utility over a bespoke GTK4 application. Expose audio,
microphone mute, Bluetooth, network, brightness, battery/power profile, night
light if available, screenshot/recording, and power actions. Waybar button,
graceful errors, focused validation, and boot-test launcher assertion.

### 5. Themed settings application
Prefer an existing free GTK4 tool if it covers requirements; otherwise a small
application using safe commands (`swaymsg`, `wpctl`, `nmcli`, `bluetoothctl`,
`brightnessctl`, `gsettings`, `systemctl --user`). Separate session vs.
system-wide settings, persist under XDG, never edit generated theme files
directly. Add launcher, failure tests, and documentation.

### 6. Display-manager theming
Retain greetd/tuigreet unless a tested GTK greeter exists in trixie. If one
exists, integrate AMOLED palette, Inter Tight, keyboard layout, accessibility,
session selection, power actions, and multi-monitor safety. Otherwise strengthen
tuigreet theming. Add BIOS/UEFI installed-boot assertions and avoid Plymouth
races.

### 7. Spotlight-style search
Keep Fuzzel as launcher. Add a small POSIX shell helper that searches
applications, recent files, home filenames, settings pages, packs, and commands.
Handle spaces, Unicode, no results, sensitive-directory exclusions, and missing
optional commands. Add quoting/path tests.

### 8. Wayland-compatible dock
Check `nwg-dock`, `nwg-panel`, and other Wayland docks in trixie. Do not add
X11-only docks. Preferred behavior: pinned apps, running apps, auto-hide,
keyboard access, multi-monitor, AMOLED theme, no fullscreen overlap, single
instance. If unavailable, implement as optional pack with Waybar fallback.

### 9. GUI package management
Use apt only; reuse `kaadzos` where possible. Support search, installed view,
install/remove, refresh, progress/errors, pack listing, and repository
explanation. Use desktop policy authorization, confirm destructive actions,
handle offline/lock states, and test with a fake apt backend.

### 10. Driver, firmware, disk, printer, and network tools
Evaluate trixie packages only. Put heavy/rare tools in a hardware/admin pack.
No boot dependency on hardware; explicit confirmation for destructive or
privileged actions. Integrate launchers into Settings and control centre.

### 11. Safe context-menu actions
Keep the file manager's native menu primary. Add safe actions (terminal here,
copy path, policy-authorized admin open, compress/extract, set wallpaper, open
settings, install local package). Handle spaces, newlines, Unicode, symlinks,
and untrusted paths. No arbitrary shell strings from filenames.

### 12. OpenCode optional pack
Do not include in base ISO. No secrets in image or artifacts. Explicit launch
and consent, clear project directory, read-only/sandboxed default, warnings
before writes/installs/network/git/destructive actions, no automatic sudo.
Declarative pack, launcher, Fuzzel entry, optional Waybar entry, dry-run tests,
and stub-based failure tests.

### 13. Complete validation and regression coverage
Extend CI without weakening gates: package availability, shell validation,
pack idempotency/dry-run, Sway warnings/duplicate bindings, Waybar startup
without hardware, Bluetooth non-fatal, launcher existence, search edge cases,
fake-apt safety, dock process safety, OpenCode secret handling, live BIOS/UEFI
boot, installed BIOS/UEFI boot, screenshots, and all existing Calamares/APT/
pack/release tests.

### 14. Documentation and release readiness
Update README.md and site docs to distinguish base features, optional packs,
hardware-dependent features, unavailable features, and security-sensitive
operations. Verify no unverified/obsolete packages, generated theme files use
`theme/generate.sh`, no secrets or non-free runtime deps, licenses documented,
ISO minimal, and `apt-recommends=false`. Run available local validation, then
trigger GitHub Actions and fix failures.

## Structural adjustments

- `policykit-1` is likely transitional; prefer `polkitd`/`pkexec` and verify.
- `p7zip-full` may be replaced by `7zip` in trixie; verify.
- `wdisplays` may be unavailable; check `nwg-displays`.
- GTK greeter availability is uncertain; keep tuigreet fallback.
- Avoid bespoke GTK4 binaries unless no suitable package exists; prefer existing
  small utilities or shell + `zenity`/`fuzzel`.
- Keep heavy features in packs to preserve the minimal ISO.

## Risks

- Package-name drift between Debian versions.
- GUI tooling increasing base ISO size.
- Build-toolchain complexity for custom applications.
- CI runtime growth from additional boot/install tests.
- Scope creep across 14 prompts.

## Implementation order

1. Verify package names in trixie.
2. Add core baseline (Prompt 2).
3. Add Bluetooth (Prompt 3).
4. Add search, control centre, and settings in order of dependency.
5. Add hardware, network, and pack management.
6. Add context menu and OpenCode pack.
7. Run full validation (Prompt 13).
8. Update documentation and release (Prompt 14).
