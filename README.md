# KaadzOS

Correct, no dual boot. GitHub Actions builds the ISO, and you only need somewhere to *boot* it. A live USB doesn't install anything or touch your disk, so even your struggling PC can try it safely (more on testing at the end).

**Step 1: Create the repo with this layout**

```
my-distro/
├── .github/workflows/build.yml
├── auto/config
└── config/
    └── package-lists/
        └── base.list.chroot
```

You can create these files right in the GitHub web editor ("Add file → Create new file"). Typing a path with slashes makes the folders for you.

**Step 2: `auto/config`** (the build settings)

```sh
#!/bin/sh
lb config noauto \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --debian-installer none \
  --apt-recommends false \
  --bootappend-live "boot=live components quiet" \
  "${@}"
```

`--apt-recommends false` is your anti-bloat switch. `--debian-installer none` skips the installer for now. We'll add Calamares later.

**Step 3: `config/package-lists/base.list.chroot`** (the shopping list)

```
linux-image-amd64
sway
waybar
foot
network-manager
firmware-linux
firmware-iwlwifi
fonts-noto-core
xwayland
```

That's enough to boot into a bare Sway session. Don't add more yet; you want the first build to succeed.

**Step 4: `.github/workflows/build.yml`**

```yaml
name: Build ISO
on: workflow_dispatch

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: debian:trixie
      options: --privileged
    steps:
      - name: Install tools
        run: |
          apt-get update
          apt-get install -y live-build git ca-certificates

      - uses: actions/checkout@v4

      - name: Build
        run: |
          chmod +x auto/config
          lb clean --purge || true
          lb config
          lb build

      - uses: actions/upload-artifact@v4
        with:
          name: iso
          path: "*.iso"
```

This replaces my earlier workflow. Building inside a Debian trixie container is more reliable than building on Ubuntu directly, and it avoids the disk-space cleanup hack.

**Step 5: Run it.** Go to the **Actions** tab, pick "Build ISO", and click **Run workflow**. Expect 15-30 minutes. When it finishes, download the ISO from the run's Artifacts section.

If it fails, which is normal for a first run, paste me the last 30 or so lines of the log and we'll fix it.

**Testing the ISO**

Options, from easiest to hardest:
1. **Live USB on any PC, including yours.** Use balenaEtcher or Ventoy (both free) to put the ISO on a USB stick, then boot from it. Nothing gets installed, and unplugging the stick returns you to normal. Sway is light, so your PC will likely handle it fine.
2. **A friend's computer**, same method.
3. **A VM**, which you skip for now since your PC is struggling.

Two things to expect on first boot: the default live login is user `user` / password `live`, and Sway won't launch automatically until we add an autostart config. That's the next step once the ISO boots.

Want me to write that next layer (autostart Sway, a dark high-contrast theme for Sway and Waybar) once your first build works?
