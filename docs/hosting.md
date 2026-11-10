# Releases and hosting

KaadzOS has no servers. GitHub Actions builds and validates the image, GitHub
Releases carries the canonical ISO assets, Cloudflare Pages serves the website
and the `iso.kaadzos.pages.dev` download host, and Cloudflare R2 mirrors release
assets and hosts the optional signed APT archive under `apt/`.

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
| `repo-test` | A throwaway signed APT repository builds and apt installs from it in a trixie container |
| `apt-repo` | (tags only) The real signed archive is built from the tagged pack definitions and published to R2 |

Only when the ISO, pack and repository tests pass does the `release` job run.
It verifies the checksum again, publishes the ISO, its SHA-256, the signed
checksum and the public key as a GitHub release, and mirrors them to R2 if R2
credentials are configured. If the release already exists, assets are replaced
(`--clobber`) and the notes are refreshed, so re-running a tag is safe.

A re-run uses the workflow file from the tag's commit. It does not pick up jobs
added later on `main`; to publish a new job such as `apt-repo`, cut a new tag
from current `main`. Moving an existing release tag is not supported.

Release notes come from `docs/release-notes/<tag>.md`. A tag without a matching
notes file falls back to GitHub's generated notes.

Useful commands:

```sh
# Cut a new release from current main (required to pick up new jobs)
tag=v0.2.0
git switch main && git pull --ff-only
git tag -a "$tag" -m "KaadzOS ${tag#v}"
git push origin "$tag"

# Re-run the whole matrix using the workflow from a tag's commit
gh workflow run build.yml --ref v0.1.0

# Inspect the published release
gh release view "$tag" --json url,assets

# Withdraw a bad release (the git tag is kept)
gh release delete "$tag" --yes
```

---

## Cloudflare Pages (website)

| Item | Value |
| --- | --- |
| Project | `kaadzos` |
| Production branch | `main` |
| URL | https://kaadzos.pages.dev |
| ISO host | https://iso.kaadzos.pages.dev (preview branch `iso`) |
| Workflow | `.github/workflows/site.yml` |
| Source | `site/` (React/Vite, builds to `site/dist/`) and `iso-site/` (advanced-mode Worker) |

Cloudflare assigns the `pages.dev` subdomain when a project is created and does
not support renaming it. The active project is named `kaadzos` in the account
selected by `CLOUDFLARE_ACCOUNT_ID` and now owns https://kaadzos.pages.dev. The
temporary suffixed subdomain existed only because the previous account's
`kaadzos` project still held the name; after that project was deleted, the
active project was deleted and recreated under the same name to claim the
unsuffixed URL. No custom domain is required.

The same Pages project exposes the exact hostname
**https://iso.kaadzos.pages.dev** as a preview **branch alias** on branch `iso`
(Cloudflare preview aliases use the form
`<branch>.<project>.pages.dev`). `site.yml` deploys `iso-site/` with
`--branch iso`; that directory contains a static landing page and
`iso-site/_worker.js`. Pages runs the file in advanced mode, so the Worker
handles every request on this hostname: `/` serves the static landing page,
`/health` reports whether the R2 binding is present, and every other path maps
directly to an R2 key (`/releases/<tag>/...`, `/apt/...`). The production
`site/` has no `_worker.js` and no `functions/`, so
https://kaadzos.pages.dev stays purely static and Worker-free.

The site is intentionally a separate design system rather than a palette
render: pure black and white, oversized fluid typography, a self-hosted Inter
Tight variable font (`site/public/fonts/`, SIL OFL), and hand-authored
`site/style.css`. `site/index.html` carries the editorial content; the palette
governs the OS surfaces, not the website.

Two React Bits accents are layered on top as progressive enhancements:
`GradientASCII` (an interactive ASCII horizon) sits below the masthead, and
`TechText` (a dashed-path `KAADZOS` wordmark) sits above the footer. The
component sources are vendored under `site/src/components/` (MIT + Commons
Clause, Copyright (c) 2026 David Haz; see the licence file there) and mounted by
`site/src/main.jsx`. Both mount points keep static fallback markup, so the page
still reads with JavaScript disabled. The build is plain React 19 + Vite:

```sh
cd site
npm ci
npm run build      # writes site/dist/
```

`site/public/` holds the files that must land at the deployment root:
`_headers`, `favicon.svg` and `fonts/`. `site/public/_headers` sets
`default-src 'none'`, `script-src 'self'`, `style-src 'self' 'unsafe-inline'`
(the components set inline styles), `font-src 'self'` and images from self plus
the CI screenshot host, along with `nosniff`, `no-referrer` and frame denial.
The repository ignores `site/node_modules/` and `site/dist/`; the workflow
builds on every run and deploys only the generated directory.

The deploy workflow is a green no-op when either secret is missing:

```sh
gh secret set CLOUDFLARE_API_TOKEN
gh secret set CLOUDFLARE_ACCOUNT_ID
```

Create an account-owned token under **Manage Account → API Tokens → Create
Token**, with the **Cloudflare Pages: Edit** permission scoped to the account;
account tokens are preferable to personal tokens for CI. The account ID is
under **Workers & Pages → Account details**.

The workflow runs `npm ci` and `npm run build` in `site/` on every run, even
when the credentials are absent, so a broken build fails CI. With credentials
present it creates the Pages project if it is missing, then runs
`wrangler pages deploy site/dist --project-name kaadzos --branch main` and
`wrangler pages deploy iso-site --project-name kaadzos --branch iso`. Pushes
that touch `site/` or `iso-site/` redeploy automatically; `workflow_dispatch`
deploys both on demand.

---

## Cloudflare R2 (ISO mirror and APT archive)

R2 has to be enabled once per account: **Workers & Pages → R2 → Enable R2**.

1. Create the bucket (default name `kaadzos`; override with the `R2_BUCKET`
   repository variable).
2. Expose it at **https://iso.kaadzos.pages.dev** without a custom domain. The
   `iso` preview branch of the Pages project runs `iso-site/_worker.js` in
   advanced mode, and the project has an `R2_BUCKET` binding to this bucket.
   Keep **Public Access** disabled and do not attach an R2 custom domain; the
   Worker reads the private bucket through the binding. Store the origin as
   `R2_PUBLIC_URL`.
3. Create upload credentials under **R2 → Manage R2 API Tokens → Create API
   Token**, with **Object Read & Write** limited to the bucket. It returns an
   Access Key ID and a Secret Access Key.
4. Store the credentials in the repository:

   ```sh
   gh secret set CLOUDFLARE_ACCOUNT_ID
   gh secret set R2_ACCESS_KEY_ID
   gh secret set R2_SECRET_ACCESS_KEY
   gh variable set R2_BUCKET --body kaadzos              # optional
   gh variable set R2_PUBLIC_URL --body https://iso.kaadzos.pages.dev
   ```

`R2_PUBLIC_URL` is the base for both the release mirror and the APT archive:
the workflows append `/releases/<tag>/` and `/apt/`. The mirror host is a
preview deployment, so Pages adds `x-robots-tag: noindex`; downloads are
unaffected. The Worker streams `GET`, `HEAD` and range requests, and R2 Public
Access stays disabled. The Workers free plan allows 100,000 requests/day, and
the CDN cache limit is 512 MB, so the 1.4 GB ISO is streamed rather than
edge-cached; a custom R2 domain can replace this path later if download volume
outgrows it.

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
cleanly, so releases still publish to GitHub while the R2 credentials and
signing key are being added. The full archive layout, key generation and
verification steps are in
[`apt-repository.md`](apt-repository.md).

---

## Current state

- Pages project `kaadzos` exists in the active account; the site is live at
  https://kaadzos.pages.dev, deployed from `main` by
  `.github/workflows/site.yml` (latest run
  [42364155141](https://github.com/KaadzOS/KaadzOS/actions/runs/42364155141))
  using the configured `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`
  secrets. The project was deleted and recreated under the exact `kaadzos` name
  after the previous account's project was deleted, so the temporary
  `kaadzos-7z2.pages.dev` URL no longer serves the site.
- The ISO host https://iso.kaadzos.pages.dev is live as the `iso` preview
  branch alias of the same project. The project has an `R2_BUCKET` binding to
  the `kaadzos` bucket for both production and preview; `iso-site/_worker.js`
  serves `/` from static assets, `/health` from the Worker, and every other
  path from R2. R2 Public Access is disabled.
- GitHub Releases: `v0.2.0`, published by CI from tag `v0.2.0` in run
  [42368854133](https://github.com/KaadzOS/KaadzOS/actions/runs/42368854133)
  (attempt 2; the first attempt published the GitHub release but hit a
  transient R2 multipart `InvalidPart` while mirroring the ISO, and the failed
  job succeeded on re-run). Assets: ISO 1,432,977,408 bytes, its 91-byte
  checksum, an 833-byte detached signature, and the 1,664-byte public keyring.
  The ISO is mirrored under `releases/v0.2.0/`.
- The `v0.1.0` release is still available; its later re-run
  [42366299998](https://github.com/KaadzOS/KaadzOS/actions/runs/42366299998)
  replaced the original 1,431,568,384-byte ISO with a 1,432,977,408-byte build
  and mirrored it under `releases/v0.1.0/`.
- The optional APT archive is live at https://iso.kaadzos.pages.dev/apt for
  `trixie main amd64`. The first package is `kaadzos-pack-defs` 0.2.0; its
  `Packages` SHA-256 matches the published `.deb`, and the `InRelease` signature
  verifies against the archive key (fingerprint
  `7FC3 1B27 E931 570B 2D8C 3E42 9A4F 8D9E 9D5B 0C7A`). The keyring, source
  stanza, and package are all served by the Worker; no user action remains for
  publishing.
