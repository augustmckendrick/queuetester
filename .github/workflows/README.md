# Workflow notes

## `RELEASE_PAT` secret

`release-new-version.yml` commits an updated `release-branches.json` to `main`
(and prunes files from the new release branch), and those pushes touch paths
under `.github/workflows/`. GitHub blocks the default `GITHUB_TOKEN` from ever
creating or updating files in `.github/workflows/`, regardless of what
`permissions:` are granted in the workflow YAML — there is no permission
scope that lifts this restriction for the automatic token. To push those
changes, the workflow instead authenticates with a personal access token
stored as the `RELEASE_PAT` repository secret.

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
