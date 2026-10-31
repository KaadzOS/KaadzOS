# KaadzOS

A bootable Debian 13 (trixie) live image with a hand-built Sway/Wayland desktop, a palette-derived theme, and an on-demand package system — built and boot-tested entirely in CI, with no build machine involved.

[![Build ISO](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml/badge.svg)](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml)

![KaadzOS live session, captured by CI](https://raw.githubusercontent.com/kaadzos/kaadzos/ci-artifacts/bios/bios.png)

*This screenshot is not staged. It is captured from the QEMU framebuffer by the boot test on every push to `main`, and the run fails if the desktop shows a configuration warning.*

---

## What it is

KaadzOS is a minimal Debian derivative: kernel, firmware, NetworkManager, Sway, Waybar, foot, fuzzel, mako, and enough tooling to be a working desktop — roughly a 1 GB hybrid ISO that boots on BIOS and UEFI. Everything heavier (AI tooling, Android apps, Windows apps, dev toolchains) is installable afterwards from declarative "packs" instead of being baked into the image.

It is an operating system I actually boot, not a config-file collection: the repository contains the live-build configuration, the theme generator, the pack manager, a Calamares installer, and the CI harness that proves the image reaches a running compositor and installs to disk.

## The constraints shaped the design

Most of the interesting decisions here are forced by the environment, and that is the point:

- **No Hyprland.** It is not in Debian stable, and this image builds from the archive with `--apt-recommends false`. Sway is in trixie, so Sway is what the desktop is built around.
- **The pack manager is POSIX `sh`, not Python or Go.** The base image ships no language runtime, and the CLI only orchestrates `apt`, `dpkg`, `curl`, and `systemctl`. A compiled binary or an interpreter would add payload to a 1 GB image to do work the shell already does.
- **Nothing is assumed about the build machine.** The ISO cannot be built or booted on the development machine, so the build, the package-resolution test, the boot test, and the install test all run in GitHub Actions against `debian:trixie`.
- **The theme has one source of truth.** `theme/palette` holds the colours; `theme/generate.sh` renders Sway, Waybar, foot, fuzzel, mako, swaylock, GTK3/4, Qt6ct, the wallpaper, the console palette, and the Calamares branding from it. Changing a colour is a one-file edit.
- **Third-party software is opt-in and signed.** The Android pack adds Waydroid's repository and key; the Cloudflare pack fetches an architecture-matched static binary. Neither is in the base image.

## How the image is verified

The build job produces `KaadzOS-trixie-amd64.iso` plus a SHA-256 file. A separate matrix job then boots that exact ISO twice, once under Syslinux/BIOS and once under GRUB/OVMF UEFI, using QEMU with KVM when available and TCG otherwise.

The boot test does not stop at "the kernel printed something":

1. It drives the Debian live boot menu over the QEMU monitor and waits for `KAADZOS_SWAY_READY` on the serial console, which is emitted only after a successful `swaymsg` IPC query.
2. It waits for the guest's diagnostics block to finish, then dumps the framebuffer.
3. **It fails the run if `swaynag` is running.** A red warning bar means the Sway config emitted an error or a shadowed binding, so an image that merely boots is not accepted.

Both firmware screenshots and serial logs are committed to the `ci-artifacts/bios` and `ci-artifacts/uefi` branches on every run, which is why the image at the top of this file is always current.

A second job, `pack-test`, resolves every pack inside a trixie container — apt names, third-party repository fields, hook syntax — and exercises the pack manager's dry-run, dependency gating, idempotency, and error paths without building an ISO. A broken pack fails in about a minute instead of at the end of a six-minute image build.

## The pack system

Packs are plain `key=value` files in `packs/`, staged into the image at build time and read at runtime by `/usr/local/bin/kaadzos`.

| Pack | What it installs | Size |
|---|---|---|
| `ai` | Ollama, whisper.cpp, Piper voice helpers | ~5 GB |
| `android` | Waydroid (signed third-party repo) | ~3 GB |
| `cloudflare` | `cloudflared` static binary | ~50 MB |
| `creative` | Image, audio, and video editing | ~1.5 GB |
| `dev` | Git, compilers, editors, Node, Python | ~900 MB |
| `gaming` | Steam, Lutris, Mesa drivers | ~2 GB |
| `privacy` | Tor, hardened browser, password manager | ~300 MB |
| `windows` | Wine and Bottles (i386 multiarch) | ~4 GB |

```sh
kaadzos list              # show packs and whether they are installed
kaadzos add dev           # install, idempotent
kaadzos remove dev
kaadzos --dry-run add ai  # print every command without running it
```

`$mod+a` opens the same list as a fuzzel menu. State lives in `/var/lib/kaadzos/installed`, so `add` and `remove` are safe to repeat.

## The installer

Phase 5 adds a Calamares installer. It does not debootstrap: it unpacks the live squashfs onto the target, then repairs the copy in place. The ordering is the hard part — `live-config` diverts `update-initramfs`, so the live-only packages have to be purged *before* the initramfs is generated, and live-only NOPASSWD sudo has to be removed before the installed system boots.

`install-test` runs the whole thing unattended in QEMU: it creates a sparse 12 GB disk, drives Calamares with `wtype`, powers off, then boots the installed disk *without* the ISO and asserts the markers that matter — `KAADZOS_MODE installed`, `KAADZOS_FIRSTBOOT_DONE`, `KAADZOS_LIVE_SUDOERS_ABSENT`, `KAADZOS_CALAMARES_ABSENT` — plus the same `swaynag` gate as the live boot.

The installer is verified end to end in CI on both BIOS and UEFI.

## What actually broke

The boot test was written because the first themed image passed every check and still looked wrong. Two Sway bindings both claimed `$mod+Shift+l` — `lock` was shadowed by `move right` — so `swaynag` painted a red error bar across an otherwise finished desktop, and nothing in the build output mentioned it.

Two changes came out of that: the lock binding moved to `$mod+Shift+x`, and the boot test gained the `swaynag` gate. A theme regression now fails CI with the framebuffer attached, instead of shipping.

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

The latest ISO and both boot screenshots are on the [Actions](https://github.com/kaadzos/kaadzos/actions/workflows/build.yml) run page as artifacts.

## Layout

```
auto/config                  live-build invocation (trixie, amd64, hybrid ISO, zstd squashfs)
config/package-lists/        base package set, no recommends
config/includes.chroot/      everything that lands in the image
  usr/local/bin/kaadzos      pack manager (POSIX sh)
  usr/local/bin/kaadzos-*    installer driver, cleanup, finalize, session readiness
  etc/calamares/             installer profile, modules, palette-generated branding
  etc/skel/.config/          Sway, Waybar, foot, fuzzel, mako, swaylock, Qt
config/hooks/live/           build-time hooks (permissions, CI profile, session readiness)
packs/                       declarative pack definitions and their hooks
theme/                       Night palette + generators for every themed surface and artwork
ci/test-boot.sh              QEMU boot validation (BIOS + UEFI)
ci/test-install.sh           unattended install + installed-disk boot validation
ci/test-packs.sh             pack resolution and CLI behaviour tests
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
| 7 — releases and hosting | not started |
| 8 — optional APT repository | not started |

There is no published release yet, so the ISO currently lives on the Actions run page. That is the next thing to fix: a tag, an ISO asset, and a checksum a stranger can verify.

## Licence

Debian components retain their own licences. The build configuration, theme generator, pack manager, installer glue, and CI harness in this repository are MIT.
