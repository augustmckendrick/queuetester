# Workflow notes

## Where things live

- **`main` branch** holds all the CI/release logic directly, with no
  stub/impl split and no separate `ciworkflows` branch: `ci-caller.yml`
  (triggered on push), `shared-ci.yml` and `deploy-pages.yml` (reusable
  `workflow_call` workflows), and `rebuild-all.yml` /
  `release-new-version.yml` (`workflow_dispatch`-triggered). This is the one
  place to edit any of that logic.
- Every **release branch** carries only a thin `ci-caller.yml` (triggered on
  push) that delegates to `shared-ci.yml@main` and `deploy-pages.yml@main`.
- **`release-management` branch** holds only `release-branches.json` at its
  root — the registry of which release branches exist, their doc version,
  title, and mike aliases. It's read by `shared-ci.yml` and
  `rebuild-all.yml` to know what to deploy, and written by
  `release-new-version.yml` when a release is cut.

## `RELEASE_PAT` secret

`release-new-version.yml` commits an updated `release-branches.json` to the
`release-management` branch, and cuts a new release branch from `main`
(pruning every workflow file from it except `ci-caller.yml`). The second of
those two pushes touches paths under `.github/workflows/`. GitHub blocks the
default `GITHUB_TOKEN` from ever creating or updating files in
`.github/workflows/` on any branch, regardless of what `permissions:` are
granted in the workflow YAML — there is no permission scope that lifts this
restriction for the automatic token. To push those changes, the workflow
instead authenticates with a personal access token stored as the
`RELEASE_PAT` repository secret.

If this token expires or needs to be rotated, recreate it as follows.

### Option A — fine-grained token (recommended)

1. Go to `github.com/settings/personal-access-tokens/new`.
2. Set **Resource owner** to this repo's owner, and **Repository access** →
   "Only select repositories" → this repo.
3. Under **Permissions → Repository permissions**, set:
   - **Contents: Read and write**
   - **Workflows: Read and write**
4. Set an expiration and generate the token, then copy it.
5. In the repo: **Settings → Secrets and variables → Actions → New repository
   secret**, name it `RELEASE_PAT`, and paste the token value.

### Option B — classic token

1. Go to `github.com/settings/tokens/new`.
2. Check the **`repo`** scope and the **`workflow`** scope (the latter is
   what unlocks writing to `.github/workflows/*`).
3. Generate the token and store it as the `RELEASE_PAT` repository secret,
   same as above.

Fine-grained tokens are scoped to just this repo with just the needed
permissions; classic tokens grant broader access across every repo the
creating account can reach.
