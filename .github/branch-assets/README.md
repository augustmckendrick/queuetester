# branch-assets

Reference copies of the workflow files that live on `main`, split by where
each one needs to go on a consuming project:

- `all-branches/ci-caller.yml` — the push-triggered delegator kept on
  `main` and every release branch.
- `main-only/rebuild-all.yml`, `main-only/release-new-version.yml` — the
  `workflow_dispatch` stubs kept on `main` only, delegating to
  `rebuild-all-impl.yml` / `release-new-version-impl.yml` here on
  `ciworkflows`.

This folder is not under `.github/workflows/`, so GitHub Actions never reads
these copies as live workflows — they're inert. They exist purely so that
everything needed to port this CI setup to another project (the real logic
on `ciworkflows`, plus the stub files a consuming branch needs) lives in one
branch. Copy `all-branches/*` into `.github/workflows/` on every branch that
needs CI, and `main-only/*` into `.github/workflows/` on the target
project's default branch only.
