# OpenCode (optional pack)

KaadzOS does not ship an AI coding agent in the base image. The `opencode`
pack is an explicit, opt-in install of the upstream OpenCode CLI. It adds no
daemon, no auto-start entry, no shell integration and no credentials.

## Install and remove

```sh
kaadzos add opencode
kaadzos remove opencode
kaadzos --dry-run add opencode
```

The pack needs network access and `curl` only at install time. There is no
Debian package for OpenCode in trixie, so the hook downloads an upstream
release archive, verifies it, and installs the binary under
`/usr/local/bin/opencode`. It also installs an **OpenCode** desktop entry,
which is not present in the base image.

## What is pinned

The hook pins the release and both supported upstream archives:

| Architecture | Asset | SHA-256 |
|---|---|---|
| amd64 (`x64`) | `opencode-linux-x64.tar.gz` | `563b5d663637226b6e3bb4bb6803281bc39b0d2cd88db06d674b6420aab009b0` |
| arm64 | `opencode-linux-arm64.tar.gz` | `9d10185acdb72336e086e699ca363a6065f410fd3c1caed0dc8046e95ac06ccb` |

The URLs point at `https://github.com/anomalyco/opencode/releases/download/v2.3.2/`.
There is no `latest` URL and no install script is piped into a shell. The
SHA-256 is checked with `sha256sum -c` before anything is extracted or
installed; a missing checksum, a different architecture or a failed download
stops the install. `ia32`, `armhf` and other architectures fail cleanly.

Upstream's `SHA256SUMS` asset for v2.3.2 lists the same two digests. Updating
the pack is a deliberate change to the pinned version and its checksums in
`packs/hooks/opencode.sh`; `kaadzos update` never changes the OpenCode binary.

## First run and privileges

The desktop entry and the Settings row run `kaadzos-opencode [DIRECTORY]`.
With no argument the project directory is your home. On the first run for a
given directory, zenity asks for confirmation and names that directory in
full. The dialog states that the agent can read and write files there and run
commands with your user privileges, and that it does not receive sudo or
credentials automatically. Cancel leaves the machine unchanged; accepting
records only the directory path in
`~/.config/kaadzos/opencode-consent`. Later runs in the same directory do not
prompt; a different directory asks again.

`kaadzos-opencode` validates the directory (no empty value, leading `-` or
control characters), never evaluates a path as shell, and launches `opencode`
in a foot terminal with that directory as its working directory. It does not
pass tokens, export API variables, enable sudo or start a service. OpenCode's
own configuration and any provider login stay in the user's account; the
KaadzOS build and CI never see them.

## Boundaries

- Not in the base ISO, not started at boot, not in the installed system until
  the pack is added.
- No third-party apt repository and no signing key are added by this pack.
- The binary is upstream MIT-licensed software from GitHub, not a Debian
  package; KaadzOS verifies the pinned archive digest at install time.
- Removing the pack deletes `/usr/local/bin/opencode` and the desktop entry.
  It does not delete the consent record or files OpenCode created in projects.
- The wlroots ScreenCast chooser is a manual check; the CI VM cannot exercise
  it, so no boot gate depends on that path.

`ci/test-opencode.sh` checks the pins, the HTTPS URL, the dash syntax, a
fixture-based download/verify/install path, arch gating, checksum failure,
dry-run behaviour, the consent flow, and a secret scan of the pack files.
Both container jobs in `.github/workflows/build.yml` run it.
