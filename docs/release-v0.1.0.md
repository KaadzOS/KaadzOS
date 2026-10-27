# Release v0.1.0 — notes and click-through

The GitHub CLI is not installed and cannot be installed on the machine this is
being prepared on. **None of this needs `gh`.** A browser is sufficient.

---

## Why this release exists

Right now the ISO only exists as a workflow artifact, which means only someone
signed in to this repository can obtain it. A reviewer cannot.

A Maker Portfolio has to be verifiable by a stranger in about a minute. A release
with an ISO and a checksum is the difference between "he says it boots" and "here,
boot it." It is the single highest-value action available, and it takes about ten
minutes.

---

## Click-through

### 1. Get the ISO

1. Repository → **Actions** → **Build ISO**.
2. Open the most recent run on `main` whose **Boot ISO** matrix is green for both
   `bios` and `uefi`.
3. Scroll to **Artifacts** → download `KaadzOS-trixie-amd64`.
4. Unzip. You should have:
   ```
   KaadzOS-trixie-amd64.iso
   KaadzOS-trixie-amd64.iso.sha256
   ```

**Before uploading**, verify the checksum locally so the published hash is known
good:

```powershell
Get-FileHash -Algorithm SHA256 KaadzOS-trixie-amd64.iso
Get-Content KaadzOS-trixie-amd64.iso.sha256
```

They must match. If they don't, stop and rebuild — do not publish a hash you
haven't checked.

### 2. Create the release

1. Repository → **Releases** → **Draft a new release**.
2. **Choose a tag** → `v0.1.0` → *Create new tag on publish*, target `main`.
3. **Release title:** `v0.1.0 — first bootable image`
4. **Description:** paste the body below.
5. Attach `KaadzOS-trixie-amd64.iso` and `KaadzOS-trixie-amd64.iso.sha256`.
6. Wait for both uploads to finish (the ISO is ~1 GB; GitHub's per-file limit is
   2 GB, so it fits).
7. **Publish release.**

### 3. Confirm from a logged-out browser

Open the release URL in a private window. Both assets must be downloadable
without signing in. If they aren't, the reviewer isn't seeing them either.

### 4. Point the README at it

Once the release exists, replace the line in `README.md`:

> There is no published release yet, so the ISO currently lives on the Actions
> run page.

with a direct link to the release, and update the Status table row for phase 7.

---

## Release body

```markdown
First bootable image. Not a finished operating system — the installer is still
in progress — but this is a real Debian 13 (trixie) live image that boots to a
working Sway/Wayland desktop on BIOS and UEFI, verified by CI on every push.

## Download

- `KaadzOS-trixie-amd64.iso` (~1 GB, hybrid ISO)
- `KaadzOS-trixie-amd64.iso.sha256`

Verify before writing to a USB stick:

    sha256sum --check KaadzOS-trixie-amd64.iso.sha256

## Write it to a USB stick

    # Linux / macOS — replace sdX with your device, this erases it
    sudo dd if=KaadzOS-trixie-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync

    # Windows
    # Use Rufus or balenaEtcher in DD mode.

The image is hybrid: the same file boots from a USB stick under BIOS or UEFI.

## What works

- Debian 13 live session, built from the archive with `--apt-recommends false`
- Sway/Wayland desktop: Waybar, foot, fuzzel, mako, swaylock
- Theme rendered from a single palette file into Sway, Waybar, foot, fuzzel,
  mako, swaylock, GTK3/4, Qt6ct, the wallpaper, the console palette, and the
  installer branding
- Eight on-demand packs (`ai`, `android`, `cloudflare`, `creative`, `dev`,
  `gaming`, `privacy`, `windows`) via `kaadzos add <pack>`, with `--dry-run`
- `$mod+a` opens the pack list as a fuzzel menu

## What does not work yet

- **The installer is in progress.** Calamares launches and renders, but the
  unattended install path is still being debugged; see the phase 5 handoff in
  `docs/`. Do not use this image to install over a disk you care about.
- No persistence, no release signing, no APT repository.

## How this build is verified

Every push builds the ISO and then boots that exact ISO twice in QEMU — once
under Syslinux/BIOS and once under GRUB/OVMF UEFI. The boot test waits for
`KAADZOS_SWAY_READY` on the serial console (emitted only after a successful
`swaymsg` IPC query), dumps the framebuffer, and **fails the run if `swaynag` is
running**, because a red warning bar means the Sway config emitted an error.

The screenshots committed to the `ci-artifacts` branch are produced by that job,
not by hand.

## Known limitations

- Builds take ~6 minutes and require ~10 GB of disk.
- The pack manager is POSIX `sh` by design; the base image ships no runtime.
- AMD64 only.
```

---

## After publishing

- [ ] Release visible logged out, both assets downloadable
- [ ] SHA-256 in the release matches the file (re-download one and check)
- [ ] `README.md` links to the release
- [ ] Phase 7 row in the status table updated
- [ ] Screenshot the release page — it is attachment-adjacent evidence
- [ ] Keep the red CI run link: it is attachment 06
