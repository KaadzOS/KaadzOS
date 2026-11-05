# Releases and hosting

KaadzOS has no servers. GitHub Actions builds and validates the image, GitHub
Releases carries the canonical ISO assets, Cloudflare Pages serves the website,
and Cloudflare R2 mirrors release assets and hosts the optional signed APT
archive under `apt/`.

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
| URL | https://kaadzos-7z2.pages.dev |
| Workflow | `.github/workflows/site.yml` |
| Source | `site/` (static, no build step) |

The project is named `kaadzos` in the account selected by
`CLOUDFLARE_ACCOUNT_ID`. Because `kaadzos.pages.dev` is still owned by the
original project in the previous account, Cloudflare assigned the suffixed
`kaadzos-7z2.pages.dev`. The original project is left untouched; attach a
custom domain or decommission it separately once the new one is established.

The site is intentionally a separate design system rather than a palette
render: pure black and white, oversized fluid typography, a self-hosted Inter
Tight variable font (`site/fonts/`, SIL OFL), hand-authored `site/style.css`,
and no JavaScript at all. `site/index.html` carries the content; the palette
governs the OS surfaces, not the website. `site/_headers` sets a strict
Content-Security-Policy (`default-src 'none'`, styles and fonts from self,
images from self plus the CI screenshot host) along with `nosniff`,
`no-referrer` and frame denial.

The deploy workflow is a green no-op when either secret is missing:

```sh
gh secret set CLOUDFLARE_API_TOKEN
gh secret set CLOUDFLARE_ACCOUNT_ID
```

Create an account-owned token under **Manage Account → API Tokens → Create
Token**, with the **Cloudflare Pages: Edit** permission scoped to the account;
account tokens are preferable to personal tokens for CI. The account ID is
under **Workers & Pages → Account details**.

The workflow creates the Pages project if it is missing, then runs
`wrangler pages deploy site --project-name kaadzos --branch main`. Pushes that
touch `site/` redeploy automatically; `workflow_dispatch` deploys on demand.

---

## Cloudflare R2 (ISO mirror and APT archive)

R2 has to be enabled once per account: **Workers & Pages → R2 → Enable R2**.

1. Create the bucket (default name `kaadzos`; override with the `R2_BUCKET`
   repository variable).
2. Expose it through a custom domain — **bucket → Settings → Custom Domains**,
   for example `iso.kaadzos.dev`. The shared `r2.dev` URL is rate-limited and
   meant for development only. Store the origin as `R2_PUBLIC_URL`.
3. Create upload credentials under **R2 → Manage R2 API Tokens → Create API
   Token**, with **Object Read & Write** limited to the bucket. It returns an
   Access Key ID and a Secret Access Key.
4. Store the credentials in the repository:

   ```sh
   gh secret set CLOUDFLARE_ACCOUNT_ID
   gh secret set R2_ACCESS_KEY_ID
   gh secret set R2_SECRET_ACCESS_KEY
   gh variable set R2_BUCKET --body kaadzos              # optional
   gh variable set R2_PUBLIC_URL --body https://iso.kaadzos.dev
   ```

The release job then uploads, over the S3-compatible endpoint
`https://<account-id>.r2.cloudflarestorage.com`:

```
releases/<tag>/KaadzOS-trixie-amd64.iso
releases/<tag>/KaadzOS-trixie-amd64.iso.sha256
releases/<tag>/KaadzOS-trixie-amd64.iso.sha256.asc   # when signing is enabled
releases/<tag>/kaadzos-archive-keyring.asc           # when signing is enabled
```

The tag-only `apt-repo` job writes the signed archive to `apt/` in the same
bucket. It also needs a dedicated GPG signing key:

```sh
gh secret set APT_GPG_PRIVATE_KEY < kaadzos-archive-private.asc
gh secret set APT_GPG_PASSPHRASE
```

Without those secrets the mirror and archive steps log a notice and exit
cleanly, so releases still publish to GitHub while R2 is being set up. The
full archive layout, key generation and verification steps are in
[`apt-repository.md`](apt-repository.md).

---

## Current state

- Pages project `kaadzos` exists in the active account; the site is live at
  https://kaadzos-7z2.pages.dev, deployed from `main` by CI run
  [42020337756](https://github.com/KaadzOS/KaadzOS/actions/runs/42020337756)
  using the configured `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`
  secrets. The original `kaadzos.pages.dev` project still exists in the
  previous account and is left untouched.
- GitHub Releases: `v0.1.0`, published by CI from tag `v0.1.0` in run
  [41322925498](https://github.com/KaadzOS/KaadzOS/actions/runs/41322925498)
  — ISO 1,431,568,384 bytes plus its 91-byte checksum.
- Pending user action: enable R2 in the active account, add the R2 S3
  credentials, and add the signing key plus `R2_PUBLIC_URL` so the ISO mirror
  and optional APT archive can publish. The checklist is in
  [`apt-repository.md`](apt-repository.md#what-you-need-to-provide).
