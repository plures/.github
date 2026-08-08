# npm Trusted Publishers (OIDC Keyless Publishing)

## Overview

The plures org uses **npm Trusted Publishers** for package publishing. This eliminates static `NPM_TOKEN` secrets in favor of OIDC-based keyless authentication provided automatically by GitHub Actions.

## How It Works

1. The reusable release workflow (`release-reusable.yml`) has `id-token: write` permission
2. `actions/setup-node` is configured with `registry-url: https://registry.npmjs.org`
3. `npm publish --provenance` uses the GitHub Actions OIDC token to authenticate
4. npm verifies that the publishing workflow matches the trusted publisher configuration on the package

No `NODE_AUTH_TOKEN` or `NPM_TOKEN` secret is required for npmjs.org publishing.

## Setup for New Packages

For each `@plures/*` package, a maintainer with **admin** access on npmjs.org must configure the trusted publisher:

1. Go to `https://www.npmjs.com/package/@plures/<package-name>/access`
2. Under **Publishing access**, click **Add trusted publisher**
3. Configure:
   - **Repository owner:** `plures`
   - **Repository name:** `.github`
   - **Workflow filename:** `release-reusable.yml`
   - **Environment:** *(leave blank)*
4. Save

> **Note:** The repository is `plures/.github` because that's where the reusable release workflow lives. Caller workflows in other repos trigger this reusable workflow, but npm verifies the workflow that actually runs `npm publish`.

## Provenance Attestations

Every published package version includes a [Sigstore](https://www.sigstore.dev/) provenance attestation that cryptographically links:
- The published package tarball
- The exact source commit
- The GitHub Actions workflow run that produced it

View attestations on any package version page on npmjs.org under the **Provenance** tab.

## Troubleshooting

### "npm ERR! 403 Forbidden"

- Verify the trusted publisher is configured for the correct repository and workflow filename
- Ensure `id-token: write` permission is set in the workflow
- Check that the package name in `package.json` matches the configured package on npmjs.org

### Provenance attestation fails

- Ensure the workflow has `id-token: write` permission
- The `--provenance` flag requires npm >= 9.5.0 (provided by `setup-node` with `node-version: lts/*`)
