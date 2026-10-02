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


---

I'm a complete beginner building a hobby Linux distro. My PC is too weak to build anything locally, so everything must build in GitHub Actions, and I only use the github.com web editor.

Create the minimal base for a Debian 13 "trixie" live ISO built with live-build. Give me ONLY these files, with full contents and exact paths:

1. auto/config
   - distribution trixie, amd64
   - archive areas: main contrib non-free-firmware
   - no Debian installer (--debian-installer none)
   - apt recommends disabled (--apt-recommends false)
   - quiet live boot

2. config/package-lists/base.list.chroot
   - Keep it tiny: kernel, firmware, NetworkManager, Sway, Waybar, foot, xwayland, one basic font. Nothing else.

3. .github/workflows/build.yml
   - Manual trigger (workflow_dispatch)
   - Runs in a debian:trixie container (privileged)
   - Installs live-build, runs the build, uploads the .iso as an artifact
   - Handle any known GitHub runner disk-space or container issues

Rules:
- Only use packages that exist in Debian trixie. If unsure about one, say so.
- Flag anything version-specific or uncertain about live-build instead of guessing.
- No theming, no extra features, no installer. The only goal is an ISO that builds and boots.
- Explain in plain language where to click in GitHub to create each file, how to run the build, and how to download the ISO.
- Also tell me how to put the ISO on a USB (Ventoy or balenaEtcher) to test it.
- If the build fails, I'll paste the last ~40 lines of the log and you'll give me the exact fix.




--- 

**Yes, opencode works for this.** It's an open-source terminal coding agent that can use many model providers, so you can plug in whichever frontier model you have access to. Your weak PC is the only catch. Don't run it locally, run it inside a **GitHub Codespace** (free monthly allowance, all the heavy lifting happens in the cloud, and you only need a browser). I'm going off memory on opencode's setup, so check opencode.ai for the current install and login steps.

**What makes an agent so much better here:** it can trigger the build and read the failure logs itself, so you stop being the copy-paste middleman:

```
gh workflow run build.yml
gh run watch
gh run view --log-failed
```

The loop becomes: agent edits, pushes, triggers the build, reads the logs, fixes, repeats. You only step in to test the ISO. Even that can be automated (Prompt 2), which suits your PC.

**Setup:** create the repo, open it in a Codespace, install opencode in the terminal, run `gh auth status` to confirm the GitHub CLI is logged in, then start with Prompt 0.

---

**Prompt 0: Project brief (save as `AGENTS.md`)**

```
Create AGENTS.md in the repo root as the persistent brief for this project, then commit it.

Project: "mydistro" (placeholder name, keep it in ONE variable/config so renaming is trivial), a Debian 13 trixie-based live/installable distro built with live-build, amd64.

Principles:
- Minimal bloat: apt recommends off, short package lists, heavy features are on-demand packs, never in the ISO.
- Dark, high-contrast, cohesive single palette, beautiful UI. Sway/Wayland stack.
- Everything builds in GitHub Actions. The dev machine is too weak to build or run VMs. Never assume local builds.
- Hosting is Cloudflare only: R2 for ISOs and apt repo, Pages for the site. No servers.
- No Hyprland (not in stable). Verify every package exists in trixie before adding it (check packages.debian.org or apt-cache in a trixie container).

Operating loop for every task: make the change, commit, trigger the workflow with gh, watch it, read failures with `gh run view --log-failed`, fix, and repeat until green. Do not ask me to paste logs. Do not move on to the next phase until the current one passes CI. Flag uncertainty about live-build behavior explicitly instead of guessing; consult the live-build manual and the actual build output.

Record decisions, palette, and phase status in AGENTS.md as we go.
```

**Prompt 1: Base ISO**

```
Phase 1. Implement the minimal live-build setup: auto/config (trixie, amd64, main contrib non-free-firmware, no d-i, apt-recommends false, hybrid BIOS+UEFI boot, zstd or xz squashfs tuned for CI time), a tiny package list (kernel, firmware-linux, NetworkManager, sway, waybar, foot, xwayland, fuzzel, one font), and .github/workflows/build.yml (workflow_dispatch, debian:trixie privileged container, live-build cache where sensible, handle runner disk space, upload the ISO plus SHA256 as artifacts). Iterate until CI produces a valid ISO. Report ISO size and build time.
```

**Prompt 2: Automated boot testing in CI (the key one for your PC)**

```
Phase 2. Add a CI job that boots the built ISO in QEMU on the runner (use KVM if /dev/kvm is available on the runner, otherwise TCG with generous timeouts), headless, with OVMF for a UEFI test and a second BIOS test. Wait for the session to come up, take a screenshot via the QEMU monitor (screendump), convert to PNG, and upload it as an artifact. Fail the job if the VM does not reach a running Sway session (detect via serial console markers, a systemd unit that logs to ttyS0, or screenshot checks). I want to see what the distro looks like without ever booting it on my own machine.
```

**Prompt 3: Session and theming**

```
Phase 3. Via config/includes.chroot: autologin on tty1, auto-start Sway, and a full dark high-contrast theme from ONE palette defined in a single source file that generates/templates the configs (Sway, Waybar, foot, fuzzel, GTK3/4, Qt via qt6ct or kvantum, cursor, icon theme, wallpaper generated as SVG or PNG, console colors). Choose tasteful typography. Add sensible Sway keybindings, a polished Waybar (workspaces, network, battery, clock, volume), notifications (mako), and a lock screen. Use CI screenshots to iterate on the look yourself until it is genuinely good. Show me the final screenshot.
```

**Prompt 4: The `mydistro` CLI and packs**

```
Phase 4. Build the `mydistro` CLI (POSIX sh or a small Python/Go single binary; justify the choice) installed into the ISO. Commands: add <pack>, remove <pack>, list, status, update. Packs live as declarative files in packs/ (apt packages, third-party apt repos with signing keys, post-install hooks, size estimate, requirements check). Implement packs: android (Waydroid with its repo, binder/kernel checks, Wayland check, first-run init), windows (Wine with i386 multiarch + Bottles), ai (Ollama via official installer, hardware detection that recommends a model size, whisper.cpp and Piper helpers), dev, gaming, creative, privacy, cloudflare (cloudflared). Add a fuzzel-based graphical "Add-ons" menu. Write tests that run in CI inside a trixie container to verify pack resolution works. Add clear errors and idempotency.
```

**Prompt 5: Installer**

```
Phase 5. Add Calamares so the ISO can install to disk: UEFI and BIOS, full-disk and manual partitioning, optional LUKS encryption, user creation, branding matching the theme, and a post-install step that removes live-only config and keeps the same Sway session. Verify trixie package availability. Extend the QEMU CI test to run an unattended install into a virtual disk, reboot into the installed system, and screenshot it.
```

**Prompt 6: Boot polish and identity**

```
Phase 6. Branding: os-release, hostname defaults, GRUB and isolinux themes, Plymouth boot splash, login/MOTD, default browser choice (pick a lean option, justify), default apps minimal set (file manager, text editor, image viewer, PDF viewer), and screenshot/screen recording tools. Check Secure Boot behavior (shim/signed GRUB from Debian) and document what works. Add zram, sensible sysctl defaults, and fast-boot tuning. Report final ISO size and idle RAM measured in the QEMU CI test.
```

**Prompt 7: Releases and hosting on Cloudflare**

```
Phase 7. Release pipeline: on a version tag, build, test, generate checksums, sign them (GPG or minisign, key stored as a GitHub secret), and upload the ISO to Cloudflare R2 via the S3 API with rclone or wrangler. Create a Cloudflare Pages landing page (static, matching the distro's palette, with download button, checksums, verification instructions, screenshots from CI, and an add-ons showcase) deployed from the repo by Actions. Provide the exact secrets I must set and the Cloudflare dashboard steps. Add a weekly scheduled rebuild so security updates are picked up.
```

**Prompt 8 (optional): Own apt repo**

```
Phase 8. Turn packs and branding into real .deb packages (mydistro-base, mydistro-theme, mydistro-cli, meta-packages per pack) built in CI with dpkg-buildpackage, published to a signed apt repository (reprepro or aptly) hosted as static files on R2 behind a custom domain. Configure the ISO to use it, so users get distro updates via normal `apt upgrade`.
```

---

**Tips for running this with frontier models:**

- Keep phase boundaries. Even strong agents drift if you hand them everything at once, and a broken early layer poisons later ones.
- Commit often and let the agent work on a branch, so a bad phase is one `git revert` away.
- Watch your CI minutes and Codespaces hours. Phase 2 and 5 tests are the heavy ones. Public repos get free Actions minutes, so keep the repo public if you're comfortable with that.
- Phase 3 is where taste matters. Give the agent reference screenshots or a vibe ("Rosé Pine but higher contrast", "pure black with one neon accent") rather than letting it pick.

Want me to tighten Prompt 3 with a few specific palette options to choose from?
