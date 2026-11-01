# Release v0.1.0 — record

**Status:** published by CI on 2026-11-01 from tag `v0.1.0` (commit `721ec6a`).

| | |
| --- | --- |
| Release | https://github.com/KaadzOS/KaadzOS/releases/tag/v0.1.0 |
| `latest` alias | https://github.com/KaadzOS/KaadzOS/releases/latest |
| Website | https://kaadzos.pages.dev |
| ISO | `KaadzOS-trixie-amd64.iso`, 1,431,568,384 bytes |
| Checksum | `KaadzOS-trixie-amd64.iso.sha256`, 91 bytes |
| CI run | [41322925498](https://github.com/KaadzOS/KaadzOS/actions/runs/41322925498) (`pack-test`, `build`, both boots, both installs, `release`) |

The release body is [`docs/release-notes/v0.1.0.md`](release-notes/v0.1.0.md);
`build.yml` reads that file when it publishes, so this document never has to be
copied by hand.

---

## How this release was produced

Pushing the annotated tag `v0.1.0` triggered the full matrix for commit
`721ec6a`. The `release` job only starts once every validation job is green:

1. `pack-test` — every pack resolves against trixie, CLI paths exercised (56 s).
2. `build` — ISO built from scratch, checksum written (6m35s).
3. `boot-test (bios)` / `boot-test (uefi)` — the exact ISO boots to
   `KAADZOS_SWAY_READY`, no `swaynag`, screenshot captured (3m18s / 2m28s).
4. `install-test (bios)` / `install-test (uefi)` — Calamares installs
   unattended and the installed disk boots (19m53s / 14m35s).
5. `release` — downloads the ISO artifact, re-runs `sha256sum --check`,
   publishes the release, then attempts the R2 mirror (1m57s).

A release therefore cannot contain an ISO that was not booted and installed by
the same run. Re-running the tag is safe: an existing release has its assets
clobbered and its notes refreshed instead of failing.

## Verified after publication

- `gh release view v0.1.0`: `draft=false`, `prerelease=false`, both assets in
  state `uploaded` with the sizes above.
- `https://github.com/kaadzos/kaadzos/releases/latest` redirects to `v0.1.0`
  without authentication.
- The `.sha256` asset downloads anonymously and names the ISO; the release job
  had already checked it against the artifact before upload.
- `https://kaadzos.pages.dev` serves the site with the CSP and security headers
  from `site/_headers`, and the CI-captured screenshot loads from the
  `ci-artifacts` branch.

## Deliberately not in this release

- **No R2 mirror.** R2 has never been enabled on the Cloudflare account
  (`code: 10042`). The workflow step is written and skips cleanly; see
  [`docs/hosting.md`](hosting.md) for the bucket and key setup.
- **No automated Pages deploy yet.** The repository has no
  `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` secrets, so `site.yml`
  is a green no-op. The first production deployment was pushed from the build
  machine with the maintainer's `wrangler` login; later `site/` changes need
  the secret (or another manual deploy).
- No release signing and no APT repository — both are phase 8 work.

## Reproducing

```sh
git checkout v0.1.0
gh workflow run build.yml --ref v0.1.0        # full matrix + release refresh
gh release download v0.1.0                    # ISO + checksum
sha256sum --check KaadzOS-trixie-amd64.iso.sha256
```
