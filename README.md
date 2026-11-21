<div align="center">
  <img src="https://raw.githubusercontent.com/kaadipranav/kaadipranav/refs/heads/main/assets/kaadzoslogo.png"/>
</div>

A bootable Debian 13 (trixie) live image with a hand-built Sway/Wayland desktop, a pure-black AMOLED theme, and an on-demand package system — built and boot-tested entirely in CI, with no build machine involved.

[![Build ISO](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml/badge.svg)](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml)

**Download:** [latest release](https://github.com/kaadzos/kaadzos/releases/latest) · **Website:** [kaadzos.pages.dev](https://kaadzos.pages.dev) · **ISO mirror:** [iso.kaadzos.pages.dev](https://iso.kaadzos.pages.dev)

![KaadzOS live session, captured by CI](https://raw.githubusercontent.com/kaadzos/kaadzos/ci-artifacts/bios/bios.png)

*This screenshot is not staged. It is captured from the QEMU framebuffer by the boot test on every push to `main`, and the run fails if the desktop shows a configuration warning.*

---

## What it is

KaadzOS is a minimal Debian derivative: kernel, firmware, NetworkManager, Bluetooth, Sway, Waybar, foot, fuzzel, mako, and enough tooling to be a working desktop — roughly a 1.4 GB hybrid ISO that boots on BIOS and UEFI. Everything heavier (AI tooling, Android apps, Windows apps, dev toolchains) is installable afterwards from declarative "packs" instead of being baked into the image.

It is an operating system I actually boot, not a config-file collection: the repository contains the live-build configuration, the theme generator, the pack manager, a Calamares installer, and the CI harness that proves the image reaches a running compositor and installs to disk.

## The constraints shaped the design

Most of the interesting decisions here are forced by the environment, and that is the point:

- **No Hyprland.** It is not in Debian stable, and this image builds from the archive with `--apt-recommends false`. Sway is in trixie, so Sway is what the desktop is built around.
- **The pack manager is POSIX `sh`, not Python or Go.** The base image ships no language runtime, and the CLI only orchestrates `apt`, `dpkg`, `curl`, and `systemctl`. A compiled binary or an interpreter would add payload to a 1 GB image to do work the shell already does.
- **Nothing is assumed about the build machine.** The ISO cannot be built or booted on the development machine, so the build, the package-resolution test, the boot test, and the install test all run in GitHub Actions against `debian:trixie`.
- **The theme has one source of truth.** `theme/palette` holds the colours; `theme/generate.sh` renders Sway, Waybar, foot, fuzzel, mako, swaylock, GTK3/4, Qt6ct, the wallpaper, the console palette, the Plymouth splash, and the Calamares branding from it. The boot-menu artwork and overrides are hand-authored from the same values. Changing a colour is a one-file edit. The OS uses a true-black AMOLED palette with a white accent, mirroring the website's black-and-white editorial design.
- **Third-party software is opt-in and signed.** The Android pack adds Waydroid's repository and key; the Cloudflare pack fetches an architecture-matched static binary. Neither is in the base image.

## How the image is verified

The build job produces `KaadzOS-trixie-amd64.iso` plus a SHA-256 file. A separate matrix job then boots that exact ISO twice, once under Syslinux/BIOS and once under GRUB/OVMF UEFI, using QEMU with KVM when available and TCG otherwise.

The boot test does not stop at "the kernel printed something":

1. It drives the Debian live boot menu over the QEMU monitor and waits for `KAADZOS_SWAY_READY` on the serial console, which is emitted only after a successful `swaymsg` IPC query.
2. It waits for the guest's diagnostics block to finish, then dumps the framebuffer.
3. **It fails the run if `swaynag` is running.** A red warning bar means the Sway config emitted an error or a shadowed binding, so an image that merely boots is not accepted.

Both firmware screenshots and serial logs are committed to the `ci-artifacts/bios` and `ci-artifacts/uefi` branches on every run, which is why the image at the top of this file is always current.

A second job, `pack-test`, resolves every pack inside a trixie container — apt names, third-party repository fields, hook syntax — and exercises the pack manager's dry-run, dependency gating, idempotency, and error paths without building an ISO. A broken pack fails in about a minute instead of at the end of a six-minute image build.

Both container jobs run `ci/test-helpers.sh`: `dash -n` and `shellcheck` over every shipped helper, then the functional suites for search, Thunar file actions, control-centre absence paths, settings persistence, fake apt (including the passwordless-sudo fallback) and the OpenCode dry-run/secret scan. The guest also emits `KAADZOS_LAUNCHER_OK`, which the boot and install gates require; it proves the helper binaries, desktop entries, Sway launcher bindings and default MIME applications are all present live and after installation.

## The pack system

Packs are plain `key=value` files in `packs/`, staged into the image at build time and read at runtime by `/usr/local/bin/kaadzos`.

| Pack | What it installs | Size |
|---|---|---|
| `admin` | Synaptic, `pkexec`, `gvfs-backends` and the polkit agent | ~45 MB |
| `ai` | Ollama, whisper.cpp, Piper voice helpers | ~5 GB |
| `android` | Waydroid (signed third-party repo) | ~3 GB |
| `cloudflare` | `cloudflared` static binary | ~60 MB |
| `creative` | Image, vector and 3D studio (GIMP, Inkscape, Krita, Blender) | ~3 GB |
| `dev` | Git, compilers, editors, Node, Python | ~900 MB |
| `fonts` | Noto core, emoji and monospace families | ~55 MB |
| `gaming` | Wine, winetricks, GameMode, MangoHud | ~2 GB |
| `hardware` | Firmware, disks, partitioning, SMART and sensors | ~300 MB |
| `input` | fcitx5 with GTK/Qt and Chinese frontends | ~20 MB |
| `network` | VPN plugins, WireGuard and NetworkManager tools | ~40 MB |
| `opencode` | Pinned upstream OpenCode coding agent (opt-in) | ~250 MB |
| `printing` | CUPS, printer drivers, scanning and mDNS discovery | ~250 MB |
| `privacy` | Tor, Unbound, MAC randomisation | ~150 MB |
| `security` | `ufw` and `gufw` firewall configuration | ~10 MB |
| `windows` | Wine and Bottles (i386 multiarch) | ~4 GB |

```sh
kaadzos list              # show packs and whether they are installed
kaadzos add dev           # install, idempotent
kaadzos remove dev
kaadzos --dry-run add ai  # print every command without running it
```

`$mod+a` opens the same list as a fuzzel menu. State lives in `/var/lib/kaadzos/installed`, so `add` and `remove` are safe to repeat.

**Base versus packs.** The base ISO carries the session, theming, installer, portals, Bluetooth stack, Thunar and its safe actions, settings/search/package helpers, default lean applications, zram and the CLI. Hardware-dependent and heavy pieces are optional: printing/scanning, firmware/disk/SMART tools, VPN plugins and firewall configuration, fonts, input methods, Synaptic, local AI, Android, Windows compatibility, creative/gaming/dev stacks, and OpenCode. Bluetooth, backlight, night light, battery and Wi-Fi are hardware-dependent even in the base: the helpers probe commands and services and hide or explain an item when the machine lacks the device. There is no dock: the Wayland dock candidates are not in trixie, and adding an X11 dock or vendored Go binary would break the minimal-Wayland rule. Waybar is the supported bar.

## Bluetooth

BlueZ and Blueman are part of the base image. `bluetooth.service` is enabled at build time, and Debian's unit carries `ConditionPathIsDirectory=/sys/class/bluetooth`: a machine with no adapter skips the service instead of failing it, and udev pulls `bluetooth.target` in when an adapter appears. The install and boot tests assert that the unit is enabled and not failed with no adapter present.

Waybar's Bluetooth module is part of the generated bar. It is muted when Bluetooth is off or unavailable, white when powered on or connected, shows the connected device name (and battery percentage when BlueZ exposes it), and underlines itself while the adapter is discovering. Left-click opens Blueman; right-click toggles adapter power; `Super+X` opens Blueman from the keyboard. The shared helper is `kaadzos-bluetooth [manager|toggle|on|off|status]`.

mako already provides `notification-daemon`, so Blueman does not pull a second notification daemon into the image. `dconf-gsettings-backend` and `libglib2.0-bin` are explicit because the image builds with `--apt-recommends false`.

## Control centre

`kaadzos-control` is one POSIX-sh helper behind the Waybar gear, `$mod+Shift+s` and the **Control Centre** desktop entry. It covers output and microphone mute, volume, the pavucontrol mixer, Bluetooth (Blueman or the power toggle), network (the connection editor when the network pack provides it, otherwise `nmcli device status`), brightness, the power profile, night light, screenshots and recording, battery status, and the session actions (lock, log out, reboot, power off).

Every optional command is probed before use: a missing tool disables one menu item with a notification instead of breaking the menu. Reboot and power off ask for confirmation when zenity is present. Night light starts `wlsunset`; when the compositor does not offer gamma control the helper reports it and leaves the rest of the session untouched.

The generated Waybar now also carries `backlight`, `power-profiles-daemon` and `idle_inhibitor` modules. Battery left-click opens the power section, and the network click falls back to the control centre when `nm-connection-editor` is absent. `upower`, `power-profiles-daemon`, `wlsunset` and `zenity` are base packages; the control centre itself adds no daemon.

## Settings

`kaadzos-settings` is the themed settings front end behind `$mod+comma` and the **Settings** desktop entry. It is one POSIX-sh + zenity helper, so it adds no daemon and no toolkit of its own. The sections are Appearance (wallpaper, night light, dark/light style, interface font and icon theme), Input (keyboard layout and touchpad tap), Display, Network, Bluetooth, Sound, Power, default browser/file manager and About.

Wallpaper, keyboard and touchpad changes are applied immediately with `swaymsg` and persisted as overrides in `~/.config/sway/config.d/`; the generated Sway config ends with `include ~/.config/sway/config.d/*.conf`, so the theme generator can keep owning the base file. Preferences live in `~/.config/kaadzos/settings.conf`. Wallpaper paths go through `kaadzos-file-action`, which validates the path and writes the override atomically instead of interpolating a filename into a shell command.

Optional tools are probed per row: `nwg-displays` or `wlr-randr` for displays, `nm-connection-editor` or `nmcli` for network, Blueman for Bluetooth, `pavucontrol` for sound, and `gsettings`/`xdg-settings`/`xdg-mime` for the desktop defaults. A missing tool disables that section with a notification rather than breaking the application. The boot and install tests require `KAADZOS_SETTINGS_OK`.

## Files

Thunar keeps its native context menu and gains safe actions from `/etc/skel/.config/Thunar/uca.xml`: **Open Terminal Here**, **Copy Path**, **Set as Wallpaper**, **Open as Administrator**, **Install Local Package** and **Open Settings**. Each command calls `kaadzos-file-action` and passes the selected path as one argv; the helper refuses names containing control characters, `$` or backticks and names beginning with `-`, and it never evaluates a filename. Thunar quotes `%f` itself, so the `uca.xml` commands leave field codes unquoted.

Archive create/extract is provided by `thunar-archive-plugin` with `xarchiver`, the lean backend that ships its own plugin tap; `7zip`, `zip`, `tar`, `gzip` and `xz-utils` are already in the base. `wl-clipboard` backs Copy Path. `gvfs`, `gvfs-fuse`, `udisks2`, `thunar-volman` and `tumbler` add trash, removable media and thumbnails, and `lxpolkit` is the session polkit agent. **Open as Administrator** uses Thunar's polkit-backed `admin://` location and requires the `admin` pack's `gvfs-backends`; install that pack before relying on the action, and log out and back in if gvfs was already running so it discovers the new backend. **Install Local Package** warns that maintainer scripts run as root, asks for confirmation, and uses `pkexec` (or live passwordless `sudo`), so it also needs the admin pack on an installed system.

The boot and install tests require `KAADZOS_FILE_ACTIONS_OK` and `KAADZOS_POLKIT_AGENT_OK`; `ci/test-file-actions.sh` exercises spaces, quotes, Unicode, symlinks, newline/`$`/backtick/leading-dash rejection, every action and the `uca.xml` wiring, and `ci/test-packages.sh` covers the local `.deb` path.

## Search

`kaadzos-search` is one POSIX-sh helper behind `$mod+d`. It builds a single fuzzel list from desktop entries, recent files in `$XDG_DATA_HOME/recently-used.xbel`, the 200 newest files from a bounded `find` over `$HOME` (depth 6, 2 s timeout), settings pages, `kaadzos list` packs and a small fixed command map, then dispatches the exact selected value: `gio launch` for applications, `xdg-open` for files, `kaadzos-settings <section>` for settings, `kaadzos add <pack>` in a foot terminal for packs, and fixed commands for lock, control centre, reload and install. `$mod+Shift+d` keeps the plain fuzzel launcher.

Scanned homes skip `.ssh`, `.gnupg`, keyrings, browser profiles, trash, caches, `node_modules` and `.git`; control-character and newline names stay out of the line-oriented list; leading-dash values are refused; and a filename is never evaluated as shell. Recent files are listed before the home scan, so they win when the scan is capped. `ci/test-search.sh` covers spaces, Unicode, recent-file decoding, missing recent state, excluded directories, dispatch for every candidate kind, cancellation and the no-`eval` rule in both container jobs.

## Packages

`kaadzos-packages` is the base zenity front page behind `$mod+Shift+p`, the Waybar box and the **Packages** desktop entry; it is also reachable from Settings. It opens Synaptic when the `admin` pack is installed, offers to install that pack, refreshes the apt lists, lists the optional packs and explains the signed archive at https://iso.kaadzos.pages.dev/apt. The `admin` pack supplies `synaptic`, `pkexec` and `gvfs-backends` (the admin:// and network/camera backends); the base image already has `zenity`, `polkitd`, `lxpolkit` and `sudo`.

Privileged front-page actions validate the package name and pass it as one argv to `apt-get` through `pkexec` (or passwordless `sudo` in the live session). A locked dpkg and an unreachable archive get distinct messages, and remove asks for confirmation with a cancel default. `kaadzos-packages install-deb PATH` backs the Thunar **Install Local Package** action: it requires an absolute readable `.deb`, warns that maintainer scripts run as root and asks for confirmation before apt sees the file. `ci/test-packages.sh` stubs apt, pkexec, zenity and Synaptic to cover refresh, install/remove confirmation, local `.deb` install, lock, offline, invalid names, pack listing and archive information without installing anything.

## OpenCode

OpenCode is optional and never in the base image. `kaadzos add opencode` downloads a pinned v2.3.2 archive from upstream GitHub releases, checks its SHA-256 against the value committed in `packs/hooks/opencode.sh`, then installs the CLI under `/usr/local/bin/opencode` and a desktop entry that is absent until the pack is added. amd64 and arm64 are supported; any other architecture fails before the download. Updating is an explicit pack change, never a silent background upgrade, and no apt repo or signing key is added.

The desktop entry and the Settings **OpenCode** row (also in search) run `kaadzos-opencode [DIR]`. The first run for a directory asks through zenity, names the directory in full, and states that the agent can read and write there and run commands as the user, with no automatic sudo or credentials. Consent is recorded per directory in `~/.config/kaadzos/opencode-consent`; cancellation changes nothing. The helper validates the path, never evaluates it as shell, and opens the agent in a foot terminal in that directory. See [`docs/opencode.md`](docs/opencode.md) for the pinned digests, update policy and security boundaries; `ci/test-opencode.sh` runs in both container jobs.

## Portals and session integration

`xdg-desktop-portal`, `xdg-desktop-portal-gtk` and `xdg-desktop-portal-wlr` are base packages. `/etc/xdg/xdg-desktop-portal/portals.conf` sends the general desktop interfaces to the GTK backend and `ScreenCast`/`Screenshot` to the wlroots backend, which is the Wayland-native path for Sway. This is what makes file pickers and screen sharing work instead of failing with "org.freedesktop.portal.Desktop was not provided by any .service files".

The live and installed sessions run Sway under a private `dbus-run-session` bus. The generated Sway config therefore calls `dbus-update-activation-environment` for both that bus and the systemd user manager, passing `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=sway`, `XDG_SESSION_TYPE`, `XDG_SESSION_DESKTOP` and `XDG_RUNTIME_DIR`. The boot and install tests activate `org.freedesktop.portal.Desktop` with a bounded `gdbus` Ping and require `KAADZOS_PORTAL_OK`.

## The installer

Phase 5 adds a Calamares installer. It does not debootstrap: it unpacks the live squashfs onto the target, then repairs the copy in place. The ordering is the hard part — `live-config` diverts `update-initramfs`, so the live-only packages have to be purged *before* the initramfs is generated, and live-only NOPASSWD sudo has to be removed before the installed system boots.

On the live desktop, launch it from the **Install** button in Waybar, with `$mod+i`, or by running `kaadzos-install` in a terminal. Do not run the raw `calamares` binary: it refuses to run as a normal user, and `sudo calamares` bypasses the wrapper that supplies `-c /etc/calamares` and preserves the Wayland environment.

`install-test` runs the whole thing unattended in QEMU: it creates a sparse 12 GB disk, drives Calamares with synthetic Sway clicks and `wtype`, powers off, then boots the installed disk *without* the ISO and asserts the markers that matter — `KAADZOS_MODE installed`, `KAADZOS_FIRSTBOOT_DONE`, `KAADZOS_LIVE_SUDOERS_ABSENT`, `KAADZOS_CALAMARES_ABSENT` — plus the same `swaynag` gate as the live boot.

The installed login is greetd plus tuigreet. `kaadzos-install-finalize` pins VT 7, keeps the AMOLED white/grey theme, adds the `KaadzOS` greeting and uses the same `%a %d %b  %H:%M` clock format as Waybar. tuigreet draws in the Linux VT font, so Inter Tight cannot be used there; a proportional font would need a compositor greeter, and the image deliberately keeps the smaller TUI path. The install test requires `KAADZOS_GREETER_OK`.

The installer is verified end to end in CI on both BIOS and UEFI.

## The optional archive

Phase 8 adds a signed APT repository on Cloudflare R2, published by CI for
`v*` tags. It carries `kaadzos-pack-defs`, the canonical pack definitions and
their hooks, so an installed system can receive new packs with `apt upgrade`
instead of a new ISO. The archive is live at https://iso.kaadzos.pages.dev/apt.
The base image does not need it: publishing is credential-gated, and the ISO
only enables the archive when the R2 credentials and signing key exist at build
time.

The repository is built and consumed by `repo-test` on every push with an
ephemeral key, so the signing path is tested even without Cloudflare. The
setup checklist and the user-facing source stanza are in
[`docs/apt-repository.md`](docs/apt-repository.md).

## What actually broke

The boot test was written because the first themed image passed every check and still looked wrong. Two Sway bindings both claimed `$mod+Shift+l` — `lock` was shadowed by `move right` — so `swaynag` painted a red error bar across an otherwise finished desktop, and nothing in the build output mentioned it.

Two changes came out of that: the lock binding moved to `$mod+Shift+x`, and the boot test gained the `swaynag` gate. A theme regression now fails CI with the framebuffer attached, instead of shipping.

## Base image contents

The base image is deliberately small. It contains the kernel and firmware, NetworkManager, BlueZ and Blueman, the control centre (upower, power-profiles-daemon, wlsunset and zenity), the settings helper, the Thunar context actions with archive/clipboard support and gvfs/udisks/thumbnail integration, the desktop portals (xdg-desktop-portal with GTK and WLR backends), Sway and its companion tools, Waybar, foot, fuzzel, mako, the Calamares installer and its runtime dependencies, greetd/tuigreet, the lean default applications (GNOME Web, Thunar, Mousepad, imv, zathura), Plymouth, zram, and an explicit core command-line baseline (`bash`, `dash`, `zsh`, `coreutils`, `util-linux`, `findutils`, `grep`, `gawk`, `tar`, `gzip`, `xz-utils`, `zstd`, `e2fsprogs`, `fdisk`, `file`, `less`, `man-db`, `manpages`, `rsync`, `tree`, `pciutils`, `usbutils`, `procps`, `lsof`, `7zip`, `unzip`, `zip`, and others). Heavier features (AI, Android, Windows, dev toolchains, printing, scanners, VPNs, hardware tools, fonts, input methods, firewall configuration, GUI package management, and OpenCode) are optional packs installed with `kaadzos add`. There is no dock pack: Waybar is the supported bar.

## Build it yourself

Requires Docker (or any Debian trixie host with `live-build`) and ~10 GB of disk.

```sh
./auto/config
mkdir -p config/includes.chroot/usr/share/kaadzos
cp -r packs config/includes.chroot/usr/share/kaadzos/packs
sudo lb build
sha256sum *.iso
```

Boot the result in QEMU, exactly as CI does:

```sh
sudo apt install qemu-system-x86 ovmf socat netpbm
bash ci/test-boot.sh bios KaadzOS-trixie-amd64.iso boot-results
bash ci/test-boot.sh uefi KaadzOS-trixie-amd64.iso boot-results
```

The latest ISO and its SHA-256 are published on the [Releases](https://github.com/kaadzos/kaadzos/releases/latest) page by CI, and every run also keeps the ISO, both boot screenshots and both install logs as [Actions](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml) artifacts.

Pushing a `v*` tag reruns the whole matrix for that commit and only then publishes the ISO, so a release cannot contain an image that was not booted and installed. The website is a small React/Vite build in `site/` (published from `site/dist/`) on Cloudflare Pages, and the ISO mirror host is a Pages branch alias that streams the private R2 bucket.

## Layout

```
auto/config                  live-build invocation (trixie, amd64, hybrid ISO, zstd squashfs)
config/package-lists/        base package set, no recommends
config/includes.chroot/      everything that lands in the image
  usr/local/bin/kaadzos      pack manager (POSIX sh)
  usr/local/bin/kaadzos-*    installer driver, cleanup, finalize, session readiness
  etc/calamares/             installer profile, modules, palette-generated branding
  etc/skel/.config/          Sway, Waybar, foot, fuzzel, mako, swaylock, Qt
  usr/share/fonts/truetype/kaadzos/
                             bundled Inter Tight (OFL)
config/hooks/live/           build-time hooks (permissions, CI profile, Calamares palette)
packs/                       declarative pack definitions and their hooks
theme/                       AMOLED palette + generators for every themed surface and artwork
site/                        black-and-white editorial site (React/Vite, builds to site/dist)
  docs/                      hand-authored documentation page (/docs/)
iso-site/                    advanced-mode Pages Worker for iso.kaadzos.pages.dev
ci/test-boot.sh              QEMU boot validation (BIOS + UEFI)
ci/test-install.sh           unattended install + installed-disk boot validation
ci/test-packs.sh             pack resolution and CLI behaviour tests
ci/test-helpers.sh           syntax, shellcheck and functional helper suites
ci/build-apt-repo.sh         signed APT repository builder (Phase 8)
ci/test-apt-repo.sh          apt consumes a throwaway signed repository
```

## Status

| Phase | State |
|---|---|
| 1 — base ISO | done |
| 2 — automated BIOS/UEFI boot testing | done |
| 3 — session and theming | done |
| 4 — pack manager and on-demand packs | done |
| 5 — installer (Calamares, install to disk) | done |
| 6 — boot polish and identity | done |
| 7 — releases and hosting | done |
| 8 — optional APT repository | done |
| 9 — installer hotfix release | done |
| 10 - AMOLED visual release | done |
| 11 - daily driver (v0.4.0) | done |

The current release, [v0.4.0](https://github.com/kaadzos/kaadzos/releases/tag/v0.4.0), is the daily-driver release: the AMOLED boot, installer, pack manager and core desktop are unchanged from 0.3.0, with portals, Bluetooth, control centre, settings, search, package helpers, helper gates, OpenCode and the security/fonts/input packs filled in. It ships the ISO, its checksum, a signed checksum and the archive keyring as GitHub release assets, and mirrors them to Cloudflare R2 under `releases/v0.4.0/`. The signed APT archive is live at https://iso.kaadzos.pages.dev/apt and carries `kaadzos-pack-defs` 0.4.0; earlier releases remain available. Releases are cut by pushing a `v*` tag; see [`docs/hosting.md`](docs/hosting.md) for the tag flow and the Cloudflare setup, and [`docs/apt-repository.md`](docs/apt-repository.md) for the optional signed package archive.

## Licence

Debian components retain their own licences. The build configuration, theme generator, pack manager, installer glue, and CI harness in this repository are MIT. Inter Tight is bundled under the SIL Open Font License; the vendored React Bits accents in `site/src/components/` are MIT + Commons Clause (full notice in `site/src/components/LICENSE.md`); OpenCode is upstream MIT-licensed software fetched only by the opt-in pack. No non-free runtime dependency is added to the ISO.
