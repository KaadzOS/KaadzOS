# The optional APT repository

KaadzOS has no servers. The optional package archive is a signed APT
repository built by GitHub Actions and published to Cloudflare R2 under
`apt/`. It carries KaadzOS-specific packages that should not require a new
ISO; the first one is `kaadzos-pack-defs`, the canonical pack definitions and
their hooks.

The base image does not need the archive. The archive is live at
https://iso.kaadzos.pages.dev/apt. Publishing is credential-gated: without the
R2 credentials and signing key the jobs are a green no-op. The image only
enables the archive when the signing key, the R2 credentials and the public
URL are present at build time **and** the published archive is reachable. The
source stanza is written by a chroot hook after package installation, so the
ISO build itself never queries an archive that has not been published yet.

---

## What the repository contains

| Path | Purpose |
| --- | --- |
| `apt/dists/trixie/InRelease` | Clear-signed `Release` file, read first by apt |
| `apt/dists/trixie/Release.gpg` | Detached signature for older clients |
| `apt/dists/trixie/main/binary-amd64/Packages{,.gz,.xz}` | Package indexes |
| `apt/pool/main/.../*.deb` | Packages in the conventional pool layout |
| `apt/kaadzos-archive-keyring.asc` | Public signing key (armored) |
| `apt/kaadzos-archive-keyring.gpg` | Public signing key (binary, for `Signed-By`) |
| `apt/kaadzos.sources` | Ready-to-copy deb822 source stanza |

The suite is `trixie`, the component is `main`, and the architecture is
`amd64` (`Architecture: all` packages are included in the amd64 index).

---

## What you need to provide

Everything below documents the one-time setup. It is already configured for
the KaadzOS account, so the archive is published by every `v*` tag; the
`repo-test` job still proves the build and signature path in CI without
credentials, and the publishing jobs skip cleanly if the credentials are
removed.

### Cloudflare

| Name | Kind | Value |
| --- | --- | --- |
| `CLOUDFLARE_ACCOUNT_ID` | secret | Account ID from the Cloudflare dashboard |
| `CLOUDFLARE_API_TOKEN` | secret | API token with **Cloudflare Pages: Edit** (for the website) |
| `R2_ACCESS_KEY_ID` | secret | R2 API token Access Key ID |
| `R2_SECRET_ACCESS_KEY` | secret | R2 API token Secret Access Key |
| `R2_BUCKET` | variable | Bucket name; defaults to `kaadzos` |
| `R2_PUBLIC_URL` | variable | Public bucket origin: `https://iso.kaadzos.pages.dev` |

`CLOUDFLARE_API_TOKEN` is for Pages and is not used by the APT job; R2 uses
the S3-compatible access key pair. `R2_PUBLIC_URL` is the public origin that
serves the bucket. For KaadzOS it is the Pages preview branch alias
`https://iso.kaadzos.pages.dev`, backed by `iso-site/_worker.js` and the
project's `R2_BUCKET` binding; R2 Public Access stays disabled. Do not use the
shared `r2.dev` URL: it is rate-limited and is not suitable for an apt
repository.

### Signing

| Name | Kind | Value |
| --- | --- | --- |
| `APT_GPG_PRIVATE_KEY` | secret | ASCII-armored private signing key |
| `APT_GPG_PASSPHRASE` | secret | Key passphrase; omit only if the key has none |

Use a dedicated signing key, not a personal one. The same key signs the APT
`Release` file and the release checksum (`KaadzOS-trixie-amd64.iso.sha256.asc`).

Generate it on a trusted machine with GnuPG:

```sh
gpg --quick-generate-key \
  "KaadzOS Archive <archive@example.com>" rsa4096 sign 5y

# Private key: add this to APT_GPG_PRIVATE_KEY, then store it offline.
gpg --armor --export-secret-keys "KaadzOS Archive" > kaadzos-archive-private.asc

# Public key: useful for checking what CI publishes.
gpg --armor --export "KaadzOS Archive" > kaadzos-archive-public.asc
```

Add the private key as a GitHub secret. The web UI is fine; if you have `gh`:

```sh
gh secret set APT_GPG_PRIVATE_KEY < kaadzos-archive-private.asc
gh secret set APT_GPG_PASSPHRASE
```

Never commit the private key. Keep an offline copy for rotation; delete the
working copy after the secret is stored.

### Cloudflare R2 setup

1. **Workers & Pages → R2 → Enable R2** (one-time per account).
2. Create a bucket, for example `kaadzos`.
3. Expose the bucket at `https://iso.kaadzos.pages.dev`: the `kaadzos` Pages
   project has an `iso` preview branch running `iso-site/_worker.js`, with an
   `R2_BUCKET` binding to this bucket. This is already configured; keep
   **Public Access** disabled and do not attach an R2 custom domain. If the
   bucket is recreated, update the Pages binding.
4. Create upload credentials: **R2 → Manage R2 API Tokens → Create API
   Token**, with **Object Read & Write** limited to the bucket. Store the
   Access Key ID and Secret Access Key as the two R2 secrets above.
5. Add the repository variables:

   ```sh
   gh variable set R2_BUCKET --body kaadzos
   gh variable set R2_PUBLIC_URL --body https://iso.kaadzos.pages.dev
   ```

The same bucket can hold the ISO mirror (`releases/<tag>/`) and the archive
(`apt/`). The paths do not collide. The `iso` branch is deployed by
`site.yml`; the Worker serves `/apt/...` and `/releases/...` from this bucket
with Public Access disabled.

---

## Publishing

The archive is published only for `v*` tags, after the full validation matrix
(build, pack test, repository test, both boots, both installs) passes. A tag
therefore publishes an ISO and an archive from the same commit.

```sh
git tag -a v0.2.0 -m "KaadzOS v0.2.0"
git push origin v0.2.0
```

The `apt-repo` job:

1. Imports `APT_GPG_PRIVATE_KEY` into a temporary `GNUPGHOME`.
2. Builds `kaadzos-pack-defs_<version>_all.deb` from the tagged `packs/` tree.
3. Runs `ci/build-apt-repo.sh`, which creates the pool, indexes, `Release`,
   `InRelease`, `Release.gpg` and both keyring formats.
4. Uploads the tree to `s3://$R2_BUCKET/apt/` through the R2 S3 endpoint.
5. Uploads the repository as an `apt-repository` Actions artifact for
   inspection.

If any of `CLOUDFLARE_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `APT_GPG_PRIVATE_KEY` or `R2_PUBLIC_URL` is missing,
the job logs a notice and exits 0. Missing archive credentials do not block the
tag's ISO release; the `repo-test` job, which needs no credentials, is still
part of the release gate.

---

## Using the archive

On an installed KaadzOS system, install the public key and source:

```sh
sudo install -d /usr/share/keyrings
curl -fsSL https://iso.kaadzos.pages.dev/apt/kaadzos-archive-keyring.asc |
  sudo gpg --dearmor -o /usr/share/keyrings/kaadzos-archive-keyring.gpg

sudo curl -fsSL https://iso.kaadzos.pages.dev/apt/kaadzos.sources \
  -o /etc/apt/sources.list.d/kaadzos.sources

sudo apt update
sudo apt install kaadzos-pack-defs
```

Or write the stanza by hand:

```sh
echo 'deb [signed-by=/usr/share/keyrings/kaadzos-archive-keyring.gpg] https://iso.kaadzos.pages.dev/apt trixie main' |
  sudo tee /etc/apt/sources.list.d/kaadzos.list
```

The archive is optional; removing the source file and keyring restores the
stock Debian-only setup.

When the image is built with `APT_GPG_PRIVATE_KEY`, the R2 credentials and
`R2_PUBLIC_URL` set and the archive is already published, the ISO ships the
keyring and source, so no manual step is needed on systems installed from that
image. If the archive is not reachable at build time (for example the first tag
that enables it), the ISO ships only the keyring; use the commands above to add
the source once `apt-repo` has published.

---

## Verifying

Check the published metadata and signature:

```sh
curl -fsSL https://iso.kaadzos.pages.dev/apt/dists/trixie/InRelease | head
curl -fsSL https://iso.kaadzos.pages.dev/apt/kaadzos-archive-keyring.asc |
  gpg --show-keys
```

Verify the repository locally after adding it:

```sh
sudo apt update
apt-cache policy kaadzos-pack-defs
```

Verify a release checksum when `KaadzOS-trixie-amd64.iso.sha256.asc` exists.
The release also carries `kaadzos-archive-keyring.asc`, so verification does
not depend on the archive being reachable:

```sh
gpg --import kaadzos-archive-keyring.asc
gpg --verify KaadzOS-trixie-amd64.iso.sha256.asc \
  KaadzOS-trixie-amd64.iso.sha256
sha256sum --check KaadzOS-trixie-amd64.iso.sha256
```

---

## Testing without credentials

`ci/test-apt-repo.sh` generates an ephemeral signing key, builds a throwaway
`kaadzos-hello` package and a signed repository, then makes apt install from
it inside the `debian:trixie` container. It also checks that `gpgv` rejects a
tampered `Release` file. The `repo-test` CI job runs this on every push that
touches the build inputs.

To run it locally in a container:

```sh
docker run --rm -v "$PWD:/src" -w /src debian:trixie sh -c '
  apt-get update &&
  apt-get install -y --no-install-recommends dpkg-dev apt-utils gnupg gpgv gzip xz-utils &&
  bash ci/test-apt-repo.sh
'
```

---

## Rotating the key

1. Generate a new key and add it as `APT_GPG_PRIVATE_KEY` (and its passphrase).
2. Re-run the tag (or push a new tag). The archive is re-signed and the new
   public key is published at `apt/kaadzos-archive-keyring.asc`.
3. Install the new keyring on systems that already added the archive. Images
   built after the rotation ship it automatically.
4. Revoke the old key once no published image depends on it.

Because the keyring is published next to the archive, a system that already
trusts the old key cannot bootstrap the new one automatically; that is the
expected trust-on-first-use boundary. Keep the old key available until the
last image that shipped it is out of support.

---

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `apt-repo` skipped | All five secrets/variables above are present |
| R2 `403` / `AccessDenied` | The R2 token has Object Read & Write on the bucket |
| `apt update` 404 | `R2_PUBLIC_URL` points at `https://iso.kaadzos.pages.dev`, and the tag's `apt-repo` job succeeded |
| `iso` host 404 | The object/path is wrong, or the release/APT publish has not run; check the tag's `release` and `apt-repo` jobs |
| `iso` host 503 / `R2 binding is not configured` | The Pages project's `R2_BUCKET` binding is missing, or the `iso` branch deployment failed |
| `NO_PUBKEY` | The keyring is installed at the path in `Signed-By` |
| `Release` signature invalid | The published key and the `InRelease` file come from the same run; re-run the tag |
