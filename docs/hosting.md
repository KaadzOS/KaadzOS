# Releases and hosting

KaadzOS has no servers. GitHub Actions builds and validates the image, GitHub
Releases carries the canonical ISO assets, Cloudflare Pages serves the website,
and Cloudflare R2 mirrors release assets (and will host the APT repository in
phase 8).

---

## Cutting a release

A release is a tag, nothing else. Push an annotated tag and CI does the rest:

```sh
git tag -a v0.1.0 -m "KaadzOS v0.1.0 — first bootable image" <commit>
git push origin v0.1.0
```

`build.yml` then runs the whole validation matrix for that commit:

| Job | What it proves |
| --- | --- |
| `pack-test` | Every pack resolves against trixie; the CLI's dry-run, gating and idempotency paths work |
| `build` | The ISO builds from scratch and the checksum file matches |
| `boot-test (bios)` / `boot-test (uefi)` | The exact ISO boots to a working Sway session under Syslinux and GRUB/OVMF, with no `swaynag` warning |
| `install-test (bios)` / `install-test (uefi)` | Calamares installs that ISO unattended and the installed disk boots |

Only when all of those pass does the `release` job run. It verifies the
checksum again, publishes the ISO and its SHA-256 as a GitHub release, and
mirrors them to R2 if R2 credentials are configured. If the release already
exists, assets are replaced (`--clobber`) and the notes are refreshed, so
re-running a tag is safe.

Release notes come from `docs/release-notes/<tag>.md`. A tag without a matching
notes file falls back to GitHub's generated notes.

Useful commands:

```sh
# Re-run the whole matrix (including the release job) for a tag
gh workflow run build.yml --ref v0.1.0

# Inspect the published release
gh release view v0.1.0 --json url,assets

# Withdraw a bad release (the git tag is kept)
gh release delete v0.1.0 --yes
```

---

## Cloudflare Pages (website)

| Item | Value |
| --- | --- |
| Project | `kaadzos` |
| Production branch | `main` |
| URL | https://kaadzos.pages.dev |
| Workflow | `.github/workflows/site.yml` |
| Source | `site/` (static, no build step) |

`site/style.css` and `site/favicon.svg` are rendered from `theme/palette` by
`theme/generate.sh`, so the website can never drift from the desktop theme.
`site/index.html` contains no colour values. `site/_headers` sets a strict
Content-Security-Policy (no scripts at all) plus `nosniff`, `no-referrer` and
frame denial.

The deploy workflow is a green no-op until both secrets exist:

```sh
gh secret set CLOUDFLARE_API_TOKEN
gh secret set CLOUDFLARE_ACCOUNT_ID
```

Create the token in the Cloudflare dashboard under **My Profile → API Tokens →
Create Token**, with the **Cloudflare Pages: Edit** permission scoped to the
account. The account ID is shown on the right-hand side of the dashboard
overview.

The workflow creates the Pages project if it is missing, then runs
`wrangler pages deploy site --project-name kaadzos --branch main`. Pushes that
touch `site/` redeploy automatically; `workflow_dispatch` deploys on demand.

---

## Cloudflare R2 (ISO mirror)

R2 has to be enabled once per account: **Workers & Pages → R2 → Enable R2**.

1. Create the bucket (default name `kaadzos`; override with the `R2_BUCKET`
   repository variable).
2. Expose it through a custom domain — **bucket → Settings → Custom Domains**,
   for example `iso.kaadzos.dev`. The shared `r2.dev` URL is rate-limited and
   meant for development only.
3. Create upload credentials under **R2 → Manage R2 API Tokens → Create API
   Token**, with **Object Read & Write** limited to the bucket. It returns an
   Access Key ID and a Secret Access Key.
4. Store the credentials in the repository:

   ```sh
   gh secret set CLOUDFLARE_ACCOUNT_ID
   gh secret set R2_ACCESS_KEY_ID
   gh secret set R2_SECRET_ACCESS_KEY
   gh variable set R2_BUCKET --body kaadzos   # optional
   ```

The release job then uploads, over the S3-compatible endpoint
`https://<account-id>.r2.cloudflarestorage.com`:

```
releases/<tag>/KaadzOS-trixie-amd64.iso
releases/<tag>/KaadzOS-trixie-amd64.iso.sha256
```

Without those secrets the mirror step logs a notice and exits cleanly, so
releases still publish to GitHub while R2 is being set up.

Phase 8 will add the APT repository under `apt/` in the same bucket.

---

## Current state

- Pages project `kaadzos` exists; the first production deployment of `site/`
  is live at https://kaadzos.pages.dev (pushed from the maintainer's `wrangler`
  login, not yet from CI).
- GitHub Releases: `v0.1.0`, published by CI from tag `v0.1.0` in run
  [41322925498](https://github.com/KaadzOS/KaadzOS/actions/runs/41322925498)
  — ISO 1,431,568,384 bytes plus its 91-byte checksum.
- Pending user action: enable R2, add the R2 credentials, and add a Pages API
  token (`CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`) so future website
  changes deploy from CI automatically.
