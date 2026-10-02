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
