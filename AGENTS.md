# KaadzOS Project Brief

KaadzOS is a Debian 13 (trixie) amd64 live and installable distribution built with live-build.

## Principles

- Keep the base ISO minimal: disable APT recommends, use short package lists, and provide heavy features only through on-demand packs.
- Use a polished, dark, high-contrast interface built around Sway and Wayland.
- Build and test entirely in GitHub Actions. Do not assume the development machine can build an ISO or run a VM.
- Use Cloudflare only for hosting: R2 for ISOs and the APT repository, and Pages for the website. Do not require servers.
- Do not use Hyprland because it is not in Debian stable.
- Verify every new package exists in trixie before adding it, using packages.debian.org, Debian's package API, or `apt-cache` in a trixie container.

## Operating Loop

For every implementation task:

1. Make the change and commit it.
2. Push the commit and trigger the relevant workflow. Pushes to `main` trigger `build.yml` automatically (as well as the manual `workflow_dispatch` entry point).
3. Watch the run and inspect failures with the GitHub API or `gh run view --log-failed`.
4. Fix, commit, and repeat until CI is green.

Do not ask the user to paste logs. Do not begin a later phase until the current phase passes CI. Consult the live-build manual and actual build output when behavior is uncertain instead of guessing.

## Decisions

- Distribution and architecture: Debian trixie, amd64.
- Image format: hybrid ISO with Syslinux for BIOS and GRUB for UEFI.
- Installer: excluded from the Phase 1 image; installation support is planned for Phase 5.
- Package policy: `--apt-recommends false`; archive areas are `main contrib non-free-firmware`.
- Root filesystem: squashfs using zstd level 10 to favor CI build time while retaining useful compression.
- Base desktop packages: Linux kernel, Debian firmware, NetworkManager, Sway, Waybar, Foot, Xwayland, Fuzzel, and DejaVu fonts.
- Artifact naming: `KaadzOS-trixie-amd64.iso` with a sibling SHA-256 checksum file.
- Boot validation: QEMU tests both Syslinux BIOS and GRUB/OVMF UEFI boots, preferring KVM and falling back to TCG.
- Session readiness: CI requires a successful Sway IPC query, emits `KAADZOS_SWAY_READY` on the serial console, and captures a screenshot. It also fails the boot test if a `swaynag` process is present, since that means the Sway config emitted errors or warnings (for example an overwritten binding).
- Palette: the "Night" palette in `theme/palette` is the single source of truth; `theme/generate.sh` renders every themed config (Sway, Waybar, foot, fuzzel, mako, swaylock, GTK/Qt, wallpaper) from it. Near-black cool base with a bright cyan-blue accent for high contrast.

## Phase Status

- Phase 1, base ISO: complete. CI run 37002963822 produced a 1000 MiB ISO; live-build took 4m54s and the complete job took 6m7s.
- Phase 2, automated BIOS/UEFI boot testing: complete. CI run 38247764091 (commit `bc8ea09`) passed `boot-test (bios)` and `boot-test (uefi)`; each reached `KAADZOS_SWAY_READY` and captured a grim screenshot. Artifacts: `KaadzOS-trixie-amd64` (ISO + SHA-256), `boot-bios`, `boot-uefi`.
- Phase 3, session and theming: complete. CI run 38521765389 (commit `9f7f3f2`) passed `build`, `boot-test (bios)` and `boot-test (uefi)`; each boot reached `KAADZOS_SWAY_READY` with no `swaynag` config-warning banner and captured a screenshot of the Night-themed desktop (accent-bordered floating terminal over the wallpaper, Waybar workspaces/clock/network/volume, mako ready). The palette-driven theme covers Sway, Waybar, foot, fuzzel, mako, swaylock, GTK3/4, Qt6ct, wallpaper and console colours. Artifacts: `KaadzOS-trixie-amd64`, `boot-bios`, `boot-uefi`. Note: the earlier CI run 38517693793 (commit `9b7ae15`) also passed, but its screenshot still showed a `swaynag` error bar from a duplicate `$mod+Shift+l` binding (lock shadowed by `move right`); this was fixed in `9f7f3f2` (lock moved to `$mod+Shift+x`) and CI now fails on any `swaynag` banner.
- Phase 4, CLI and on-demand packs: not started.
- Phase 5, installer: not started.
- Phase 6, boot polish and identity: not started.
- Phase 7, releases and Cloudflare hosting: not started.
- Phase 8, optional APT repository: not started.
