# Phase 5 handoff — Calamares installer

Status: **in progress, not complete.** The guest-side installer, the CI-only
Calamares profile, the installed-system login/first-boot handling and the
installer artwork are written and pass local static checks. The unattended
install test (`ci/test-install.sh`) and the `install-test` CI job do **not**
exist yet, so no CI run has installed KaadzOS to a disk or booted the installed
system. Phase 6 must not start until the install test is green.

Date: 2026-10-26
Base commit before this handoff: `029571c` (Phase 4 complete)

## State at a glance

| Area | State |
| --- | --- |
| Calamares packages in `base.list.chroot` | written; YAML/package names checked locally, not installed in CI yet |
| Normal installer config (`/etc/calamares`) | written; all used modules have a config; YAML parses |
| CI-only Calamares profile (`/etc/calamares-ci`) | written; staged by a live-build hook |
| Unattended UI driver (`kaadzos-ci-install`) | written; triggers on DMI product name |
| Live → target cleanup and finalize scripts | written |
| Installed-system greetd/tuigreet login | written |
| Installed-system first-boot cleanup | written |
| Sway/Waybar/theme integration | written; wallpaper regenerated |
| Calamares branding/artwork | written; generated from `theme/palette` |
| `ci/test-install.sh` | **not started** |
| `install-test` jobs in `.github/workflows/build.yml` | **not started** |
| Phase 5 CI green | **not yet** |
| `AGENTS.md` Phase 5 status | not updated (only update after CI is green) |

What the current push validates: the `build` job (package availability, ISO
build) and the existing `boot-test (bios)`/`boot-test (uefi)` jobs. It does not
validate installation.

## Installer design

The installer does not debootstrap. It copies the live squashfs to the target
with Calamares `unpackfs`, then repairs the copy in place:

1. `partition`, `mount`, `unpackfs` copy `/run/live/medium/live/filesystem.squashfs`
   onto the target.
2. `kaadzos-install-live-cleanup` runs immediately after `unpackfs` and
   **before** `initramfs`. It purges `live-config-systemd`, `live-config`,
   `live-boot-initramfs-tools`, `live-boot` and `live-tools` from the target.
   This ordering is mandatory: live-config diverts `update-initramfs`, so an
   initramfs generated before the purge is broken.
3. The normal Calamares modules configure machine-id, fstab, locale, keyboard,
   user, display manager, network, hwclock, services, bootloader, GRUB and the
   initramfs.
4. `kaadzos-install-finalize` removes live-only sudo, the CI Calamares profile
   and the installer helper scripts from the target, forces greetd to VT 7,
   makes `graphical.target` the default, repair empty APT sources, and writes
   `/etc/kaadzos/installed`.
5. `/etc/calamares` and the `calamares` package are kept until the installed
   system's first boot so installer logs/branding remain available.
6. `kaadzos-firstboot.service` runs before greetd on the installed system,
   purges Calamares, removes `/etc/calamares`, writes
   `/etc/kaadzos/firstboot-done`, and disables itself.

Installer execution order (`config/includes.chroot/etc/calamares/settings.conf`):

```
show: welcome, locale, keyboard, partition, users, summary
exec: kaadzos-exec-marker, partition, mount, unpackfs,
      kaadzos-cleanup, machineid, fstab, locale, keyboard, localecfg,
      users, displaymanager, networkcfg, hwclock, services-systemd,
      bootloader, grubcfg, initramfs, kaadzos-finalize, umount
show: finished
```

The three `kaadzos-*` exec entries are `shellprocess` instances declared in
`instances:` and have their own configs in `modules/`.

### Installer files

| Path | Purpose |
| --- | --- |
| `config/package-lists/base.list.chroot` | Calamares, squashfs-tools, Python 3 + toml, Qt6 Wayland/QML, partition/boot tools, locales/keyboard, greetd, tuigreet, wtype |
| `config/includes.chroot/etc/calamares/settings.conf` | normal installer sequence |
| `config/includes.chroot/etc/calamares/modules/*.conf` | module configs + the three `shellprocess` configs |
| `config/includes.chroot/etc/calamares/branding/kaadzos/` | generated branding: `branding.desc`, `stylesheet.qss`, `show.qml`, `logo.png`, `welcome.png`, `slide.png` |
| `config/includes.chroot/usr/local/bin/kaadzos-install` | normal launcher: re-execs Calamares through `sudo -E`, preserving the Wayland environment |
| `config/includes.chroot/usr/local/bin/kaadzos-ci-install` | CI-only `wtype` driver; reads DMI product name |
| `config/includes.chroot/usr/local/bin/kaadzos-install-live-cleanup` | target purge after `unpackfs` |
| `config/includes.chroot/usr/local/bin/kaadzos-install-finalize` | target cleanup + marker before `umount` |
| `config/includes.chroot/usr/local/bin/kaadzos-firstboot` | first-boot Calamares purge |
| `config/includes.chroot/etc/systemd/system/kaadzos-firstboot.service` | first-boot unit, ordered `Before=greetd.service`, guarded by `/etc/kaadzos/installed` |
| `config/includes.chroot/usr/share/applications/kaadzos-install.desktop` | desktop entry for fuzzel |
| `config/hooks/live/0500-calamares-ci.hook.chroot` | copies `/etc/calamares` → `/etc/calamares-ci`, overlays CI files, disables greetd in the live image, enables firstboot |
| `config/includes.chroot/usr/share/kaadzos/ci/calamares/` | CI `settings.conf` + `modules/{finished,partition,users}.conf` overlay |

### Normal installer choices

- Partitioning: full-disk erase, install-alongside and manual are all exposed;
  `initialPartitioningChoice: none` forces an explicit choice. Swap choices are
  none/small/file. LUKS is available on the automated and manual pages; LUKS1
  is used because trixie GRUB can unlock it without extra initramfs help.
- Users: normal installs show empty full-name/login-name fields; autologin is
  off; the user is in `sudo`; root password setting is disabled.
- Login: greetd + tuigreet on the installed system. Calamares 3.3.14 detects
  `/usr/bin/tuigreet` in the target and writes a `tuigreet --cmd
  /usr/local/bin/kaadzos-sway-session` default session automatically; no
  finalize override for the command is needed. Finalize only sets
  `terminal.vt = 7` and keeps `default_session.user = "_greetd"`.
- Bootloader: GRUB for BIOS (`grub-pc-bin`) and UEFI (`grub-efi-amd64-bin`,
  `efibootmgr`), with `installEFIFallback: true`. Kernel parameters include
  `quiet console=tty0 console=ttyS0,115200n8` so CI can read the installed boot.
- Sources: if the target has no APT sources after unpacking, finalize writes
  trixie main/contrib/non-free-firmware, trixie-updates and trixie-security.

## CI-only profile and unattended driver

`0500-calamares-ci.hook.chroot` copies the normal profile and overlays:

- `settings.conf`: `disable-cancel: true`, `quit-at-end: true`.
- `partition.conf`: `initialPartitioningChoice: erase`, no swap, no LUKS.
- `users.conf`: full name `KaadzOS`, login `kaadzos`, password
  `kaadzos2026` (11 chars, minLength 8), autologin enabled, no root password.
  The installed system therefore boots straight into Sway for observation.
- `finished.conf`: `restartNowMode: never`; the driver powers the VM off.

The driver is started from the Sway autostart only when **all** of these hold:

- `/sys/class/dmi/id/product_name` is readable and equals
  `KAADZOS-CI-INSTALL`;
- `/etc/calamares-ci` exists;
- `/etc/kaadzos/installed` does not exist;
- `/run/kaadzos-ci-install.started` does not exist.

`product_name` is used deliberately: `/sys/class/dmi/id/product_serial` is
root-only, so the unprivileged live user cannot read it. The install test must
set the product name, not the serial:

```
-smbios type=1,product=KAADZOS-CI-INSTALL
```

The QEMU option is `-smbios`; the value above is the exact product name the
guest compares against.

Driver sequence (`kaadzos-ci-install`):

1. Write `KAADZOS_INSTALLER_START` to `/dev/ttyS0`.
2. Wait 10 s, kill the welcome `foot`, start Calamares as root with
   `sudo -E env HOME=/root QT_QPA_PLATFORM=wayland /usr/bin/calamares -c
   /etc/calamares-ci`, logs to `/tmp/calamares-ci.log`.
3. Poll `swaymsg -t get_tree` for `"app_id": "calamares"` (180 s), then
   fullscreen it and write `KAADZOS_INSTALLER_WINDOW`.
4. Navigate with `wtype`: Alt+N through welcome → locale → keyboard →
   partition; 40 s pause after keyboard for the device scan; 5 s after
   partition; on users, 3 Tabs from the full-name field to the password box,
   type the password, Tab, type it again, Alt+N; on summary, Alt+I.
5. Wait for Calamares to exit, with a 40-minute watchdog. Emit
   `KAADZOS_CI_STEP name`, `KAADZOS_INSTALL_EXIT rc=N`,
   `KAADZOS_INSTALL_WATCHDOG` on timeout, and a bounded Calamares log tail
   between `KAADZOS_CI_LOG_BEGIN`/`END`.
6. `sudo -n poweroff -f` so the host can reboot the disk.

Markers used by the runner: `KAADZOS_INSTALLER_START`,
`KAADZOS_INSTALLER_WINDOW`, `KAADZOS_CI_STEP`, `KAADZOS_INSTALL_EXEC_BEGIN`
(from the exec-marker shellprocess), `KAADZOS_INSTALL_EXIT`,
`KAADZOS_INSTALL_WATCHDOG`, `KAADZOS_CI_LOG_BEGIN/END`.

## Installed-system behaviour

- `kaadzos-sway-session` is used by both the live autologin and greetd. It
  exports `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=sway`,
  `XDG_SESSION_DESKTOP=sway`, `QT_QPA_PLATFORMTHEME=qt6ct`, runs Sway inside
  `dbus-run-session` and logs to `/tmp/sway.log`. It forces the pixman
  renderer only when DMI indicates QEMU; real hardware keeps the default.
- `kaadzos-session-ready` writes `KAADZOS_MODE live|installed`, waits for
  `swaymsg -t get_outputs`, checks config/log processes, and in installed mode
  emits `KAADZOS_LIVE_SUDOERS_ABSENT/PRESENT`, `KAADZOS_CALAMARES_ABSENT/PRESENT`
  and `KAADZOS_FIRSTBOOT_DONE/PENDING`, then a `KAADZOS_DIAG_BEGIN/END` block
  (outputs, tree, processes, firstboot marker, relevant logs). `swaynag`
  presence is reported as `KAADZOS_SWAY_CONFIG_WARNINGS`; the boot test fails
  on it and the install test should too.
- First boot runs `kaadzos-firstboot` before greetd: `dpkg --purge calamares`,
  removes `/etc/calamares`, `/etc/calamares-ci`, `/etc/live`,
  `/usr/share/kaadzos/ci` and the installer helpers, writes
  `/etc/kaadzos/firstboot-done`, disables itself and prints
  `KAADZOS_FIRSTBOOT_DONE`.
- The live image keeps greetd disabled and boots tty1 autologin; the target
  enables greetd and `graphical.target`. The CI profile enables autologin so
  the installed desktop can be observed without greeter interaction.

## Theme and artwork

- `theme/palette` remains the single source of truth.
- `theme/render-artwork.py` is a pure-Python PNG renderer (no ImageMagick, no
  font files) for `wallpaper.png` and the Calamares `logo.png`, `welcome.png`
  and `slide.png`. It takes the palette colours as arguments.
- `theme/generate.sh` still writes every themed text config and now calls
  `render-artwork.py` when `python3`/`python` is available. The generated PNGs
  are committed because CI does not run `theme/generate.sh`.
- `show.qml` uses `Presentation` API 2; `textColor`, `fontFamily`,
  `activatedInCalamares` and `centeredText` are valid in Calamares 3.3.14.
- The Calamares window is `1000px,650px`; the Sway config fullscreens
  `app_id="calamares"` for the live session.

## Verification performed before handoff

- All 25 Calamares/CI YAML files parse with PyYAML.
- `sh -n` passes for every shell script and live-build hook; the renderer
  compiles with Python 3.11.
- Package names checked against trixie: `calamares 3.3.14-1`, `tuigreet
  0.9.1-5`, `wtype 0.4-3` (amd64), `greetd 0.10.3-4`, plus the partition/boot
  tooling. The workflow's `apt-cache show` step will re-check all of them.
- Upstream source checks: `-c` app-data option works; `displaymanager`
  auto-selects tuigreet; `users` creates missing default groups
  (`SetupGroupsJob`), so `scanner`/`lpadmin`/`bluetooth`/`netdev` cannot fail
  user creation; `finished` accepts `restartNowMode: never`; `partition`
  accepts `initialPartitioningChoice: none|erase`; greetd's `_greetd` user is
  created by its postinst; `base-passwd` guarantees `cdrom`, `floppy`, `sudo`,
  `audio`, `dip`, `video`, `plugdev`, `dialout`.
- Fixed during handoff: CI detection now uses world-readable
  `/sys/class/dmi/id/product_name` instead of root-only `product_serial`, in
  both the Sway autostart guard and the driver.

## Remaining work (in order)

1. Write `ci/test-install.sh`.
2. Add an `install-test` job (matrix `bios`/`uefi`) to
   `.github/workflows/build.yml`, `needs: build`.
3. Push and iterate until both install jobs and the existing jobs are green.
4. Only then update `AGENTS.md` with the Phase 5 status and the evidence run.

### `ci/test-install.sh` plan

Signature: `ci/test-install.sh <bios|uefi> <iso> <output-directory>`.

Install boot:

- `qemu-img create -f qcow2 "$output_dir/disk.qcow2" 12G` (sparse; do not
  preallocate 12 GiB on the runner).
- QEMU args modelled on `ci/test-boot.sh`: `-machine q35`, `-m 2048` (or
  4096), `-smp 2`, KVM if usable else TCG, `-device virtio-vga`, `-display
  none`, serial file, monitor unix socket, `-no-reboot`.
- Disk: `-drive file=$disk,if=virtio,format=qcow2`.
- ISO: `-drive file=$iso,media=cdrom,readonly=on`; `-boot order=d,menu=on`.
- DMI: `-smbios type=1,product=KAADZOS-CI-INSTALL`.
- UEFI: copy `OVMF_VARS_4M.fd` (fallback `OVMF_VARS.fd`) to the output
  directory; `-drive if=pflash,format=raw,readonly=on,file=OVMF_CODE...` and
  `-drive if=pflash,format=raw,file=$vars_copy`. Reuse this copy on the
  installed-disk boot.
- Send `ret` to the boot menu three times as `test-boot.sh` does.

Wait for `KAADZOS_INSTALL_EXIT rc=0` with a bounded loop (50 minutes under
TCG). Fail if `KAADZOS_INSTALL_WATCHDOG`, `KAADZOS_INSTALLER_WINDOW_TIMEOUT`
or a nonzero rc appears. Capture a monitor `screendump` when
`KAADZOS_INSTALL_EXEC_BEGIN` appears and when `KAADZOS_INSTALLER_WINDOW`
appears (PPM → PNG with `pnmtopng`). Wait for QEMU to exit after the guest
powers off (the driver does `sudo -n poweroff -f`).

Installed-disk boot:

- Start a new QEMU with the same disk, same OVMF vars for UEFI, **no ISO**,
  `-boot order=c`, a fresh serial file and monitor socket.
- Keep `-smbios type=1,product=KAADZOS-CI-INSTALL` (harmless: the target has no
  `/etc/calamares-ci`; it also keeps the QEMU renderer path).
- Wait for `KAADZOS_MODE installed`, `KAADZOS_SWAY_READY`,
  `KAADZOS_FIRSTBOOT_DONE`, `KAADZOS_LIVE_SUDOERS_ABSENT`,
  `KAADZOS_CALAMARES_ABSENT`, and `KAADZOS_DIAG_END` (bounded, ~10 min).
- Fail on `KAADZOS_SWAY_CONFIG_WARNINGS`, `KAADZOS_FIRSTBOOT_PENDING`,
  `KAADZOS_LIVE_SUDOERS_PRESENT`, `KAADZOS_CALAMARES_PRESENT`, or a missing
  marker.
- Capture a final screenshot. Optionally assert it is not blank (the existing
  boot test only checks the PNG is non-empty).
- Upload the install serial log, installed serial log, both screenshots, QEMU
  logs and OVMF vars copy.

Workflow plan:

```yaml
install-test:
  needs: build
  runs-on: ubuntu-latest
  timeout-minutes: 70
  strategy:
    fail-fast: false
    matrix:
      firmware: [bios, uefi]
  steps:
    - checkout
    - download artifact KaadzOS-trixie-amd64
    - verify sha256
    - sudo apt-get install --yes qemu-system-x86 qemu-utils ovmf socat netpbm
    - bash ci/test-install.sh "${{ matrix.firmware }}" artifacts/KaadzOS-trixie-amd64.iso install-results
    - upload install-results (always)
```

Check runner free space before allocating the disk; GitHub-hosted Ubuntu
runners are usually fine for a sparse 12 GiB qcow2 plus a ~1 GiB ISO, but the
install writes several GiB.

## Known risks / likely failure points

1. **UI automation is the highest risk.** The driver assumes Alt+N mnemonics,
   `app_id` exactly `calamares`, the users-page tab order (full name → login →
   hostname → password → verify), and that Next is enabled within the sleeps.
   If the app-id differs, the 180 s window wait times out; if the tab order
   differs, the password lands in the wrong field; if the partition page has
   not preselected the single virtio disk, Next stays disabled.
2. **DMI detection** was fixed to `product_name`; the install test must use
   `-smbios type=1,product=KAADZOS-CI-INSTALL` (the old serial plan would not
   work for the unprivileged live user).
3. **UEFI NVRAM / boot order**: reuse the OVMF vars file from the install boot
   and detach the ISO for the installed boot; otherwise OVMF may boot the ISO
   again.
4. **`unpackfs` + live purge + initramfs**: ordering is implemented, but this
   is the first real install. Watch for `update-initramfs` failures,
   `apt-get purge` failures in the target, or a missing `/boot` initrd.
5. **policy-rc.d**: the target's `apt-get purge` may invoke service scripts.
   live-build likely provides a policy-rc.d in the build chroot, and many
   Debian postinsts tolerate the chroot, but if the purge fails this is a
   candidate cause. A narrow fix is to create `/usr/sbin/policy-rc.d` in the
   target before the purge and remove it in finalize (marker the fact that we
   created it).
6. **greetd/tuigreet**: Calamares 3.3.14 auto-detects tuigreet and writes the
   command; finalize sets `vt = 7`. Still unvalidated in the installed VM.
   If the greeter is not reached, check `/etc/greetd/config.toml` after
   install (before first boot purges Calamares) and the greetd journal.
7. **First boot**: `kaadzos-firstboot` purges Calamares as root before greetd.
   If `dpkg --purge` fails, the unit stops before writing
   `/etc/kaadzos/firstboot-done`; the install test will report
   `KAADZOS_FIRSTBOOT_PENDING`.
8. **ISO size/time**: Calamares/Qt6/greetd add payload and build time. There is
   no hard size limit in the brief, but watch the 20-minute boot-test timeout
   and the runner disk.
9. **Install time under TCG**: the 40-minute driver watchdog and 70-minute job
   timeout are deliberate; if the runner has KVM this is much faster.
10. **Calamares package has no default configs**; every used module relies on
    our `/etc/calamares/modules` files. YAML parses, but a module may still
    require a key we omitted; the install log tail will show it.

## Resume commands

```sh
git status
git log --oneline -5
gh run list --workflow build.yml --limit 5
gh run view <run-id> --log-failed
gh run view <run-id> --web
```

To run the workflow manually:

```sh
gh workflow run build.yml
gh run watch <run-id>
```

Artifacts:

```sh
gh run download <run-id> -n KaadzOS-trixie-amd64 -D artifacts
gh run download <run-id> -n install-bios -D install-results/bios
gh run download <run-id> -n install-uefi -D install-results/uefi
```

Note: the development machine cannot build an ISO or run a VM; all validation
is in GitHub Actions (per `AGENTS.md`).

## Notes

- `session-ses_ee4d.md` in the repo root is an unrelated OpenCode session
  export and is intentionally not committed.
- The logo/branding design is the user's responsibility; the installer
  artwork here is only the palette-driven placeholder render.
- `theme/__pycache__/` is generated and ignored; do not commit it.
- Keep the palette as the single source of truth; do not hand-edit generated
  Sway/Calamares/Waybar configs.
- Phase 5 is done only when `build`, `pack-test`, `boot-test (bios)`,
  `boot-test (uefi)`, `install-test (bios)` and `install-test (uefi)` are all
  green.
