Create AGENTS.md in the repo root as the persistent brief for this project, then commit it.



Project: "KaadzOS", a Debian 13 trixie-based live/installable distro built with live-build, amd64.



Principles:

\- Minimal bloat: apt recommends off, short package lists, heavy features are on-demand packs, never in the ISO.

\- Dark, high-contrast, cohesive single palette, beautiful UI. Sway/Wayland stack.

\- Everything builds in GitHub Actions. The dev machine is too weak to build or run VMs. Never assume local builds.

\- Hosting is Cloudflare only: R2 for ISOs and apt repo, Pages for the site. No servers.

\- No Hyprland (not in stable). Verify every package exists in trixie before adding it (check packages.debian.org or apt-cache in a trixie container).



Operating loop for every task: make the change, commit, trigger the workflow with gh, watch it, read failures with `gh run view --log-failed`, fix, and repeat until green. Do not ask me to paste logs. Do not move on to the next phase until the current one passes CI. Flag uncertainty about live-build behavior explicitly instead of guessing; consult the live-build manual and the actual build output.



Record decisions, palette, and phase status in AGENTS.md as we go.

