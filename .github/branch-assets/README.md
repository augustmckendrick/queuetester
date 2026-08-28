# branch-assets

Reference copies of the workflow files that live on `main` (and get copied
into every new release branch, in the case of `ci-caller.yml`):

- `ci-caller.yml` — the push-triggered delegator kept on `main` and every
  release branch.
- `rebuild-all.yml` / `release-new-version.yml` — the `workflow_dispatch`
  stubs kept on `main` only, delegating to `rebuild-all-impl.yml` /
  `release-new-version-impl.yml` here on `ciworkflows`.

This folder is not under `.github/workflows/`, so GitHub Actions never reads
these copies as live workflows — they're inert. They exist purely so that
everything needed to port this CI setup to another project (the real logic
on `ciworkflows`, plus the stub files a consuming branch needs) lives in one
branch. Copy them into `.github/workflows/` on the target project's default
branch to wire it up there.
