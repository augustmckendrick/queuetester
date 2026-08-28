# Workflow notes

## Where things live

- **`ciworkflows` branch** holds the actual CI/release logic: `shared-ci.yml`,
  `deploy-pages.yml`, `rebuild-all-impl.yml`, `release-new-version-impl.yml`,
  and `release-branches.json`. This is the one place to edit any of that
  logic.
- **`main`** and every **release branch** carry only a thin `ci-caller.yml`
  (triggered on push) that delegates to `shared-ci.yml@ciworkflows` and
  `deploy-pages.yml@ciworkflows`.
- **`main`** additionally carries two `workflow_dispatch` stubs,
  `rebuild-all.yml` and `release-new-version.yml`, that each delegate to the
  matching `*-impl.yml` workflow on `ciworkflows`. These stubs have to live on
  `main` (rather than moving to `ciworkflows` with everything else) because
  GitHub only shows the "Run workflow" button, and only allows triggering
  `workflow_dispatch` at all, for workflow files present on the repository's
  default branch.

## `RELEASE_PAT` secret

`release-new-version-impl.yml` commits an updated `release-branches.json` to
`ciworkflows`, and cuts a new release branch from `main` (pruning every
workflow file from it except `ci-caller.yml`). Both of those pushes touch
paths under `.github/workflows/`. GitHub blocks the default `GITHUB_TOKEN`
from ever creating or updating files in `.github/workflows/` on any branch,
regardless of what `permissions:` are granted in the workflow YAML — there is
no permission scope that lifts this restriction for the automatic token. To
push those changes, the workflow instead authenticates with a personal
access token stored as the `RELEASE_PAT` repository secret.

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
