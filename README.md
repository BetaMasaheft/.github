# .github

Org-wide defaults and shared CI for the [BetaMasaheft](https://github.com/BetaMasaheft) organization. This is GitHub's special [`.github` repository](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) - its contents apply across every repo in the org unless a repo overrides them locally.

## Contents

- `profile/README.md` - the org's public profile page (shown on [github.com/BetaMasaheft](https://github.com/BetaMasaheft)).
- `workflow-templates/` - starter workflows offered to any org member creating a new workflow in any repo (Actions tab → New workflow). Copy-and-customize, not called by reference.
- `.github/workflows/install-smoke.yml` - a reusable workflow (`workflow_call`), called by reference from a consuming repo's own workflow file, not copied.
- `test/install-smoke.bats` - the bats suite `install-smoke.yml` runs; shared so a fix lands once instead of once per consuming repo.
- `.github/dependabot.yml` - dependency update config for this repo.

## Workflow templates

Shown as starter options when creating a new workflow anywhere in the org - each is a one-time copy into the target repo, not a live link back here.

| Template | File | What it does |
| --- | --- | --- |
| Validate Changed Files | `workflow-templates/validate_pr.yml` | On a PR, validates only the TEI/XML files it actually touches against `BetaMasaheft/Schema`'s RelaxNG schema. |
| Validate on Push to Default Branch | `workflow-templates/validate_push.yml` | On push to the default branch, validates every TEI/XML file in the repo, then builds the expath package (`ant`). |
| Exist Expath Package | `workflow-templates/exist_package.yml` | Builds a repo's own xar and installs it into eXist by mounting it into `/exist/autodeploy`, then runs `test/*.bats`. Predates `install-smoke.yml` below and has the same limitation the reusable workflow was built to fix: no dependency resolution, only works for a self-contained package. New repos with any expath dependency should use `install-smoke.yml` instead; this template is kept for repos that already use it and have no dependencies. |

## Reusable workflow: `install-smoke.yml`

Builds a repo's own xar, installs it into a bare eXist via `xst` (dependency-aware, unlike the `exist_package.yml` template above), and runs the shared `test/install-smoke.bats` suite against it. See [BetaMasaheft/BetMasApi#29](https://github.com/BetaMasaheft/BetMasApi/pull/29) for the CI work this was distilled from, and [BetaMasaheft/Works](https://github.com/BetaMasaheft/Works)' `.github/workflows/smoke.yml` for a live example of calling it.

Minimal caller, for a repo with no dependencies:

```yaml
name: Install smoke
on:
  push:
    branches: [master, main]
  pull_request:
    branches: [master, main]

jobs:
  smoke:
    uses: BetaMasaheft/.github/.github/workflows/install-smoke.yml@main
```

Every input is optional and defaults to the common case - only set what a given repo actually needs:

| Input | Default | When to set it |
| --- | --- | --- |
| `package-uri` | read from the caller's own `expath-pkg.xml` `name` attribute | Only if that auto-derivation is wrong for some reason. |
| `existdb-image` | `duncdrum/existdb:release-slim` | A different base image to install against. |
| `java-version` | `"8"` | A different JDK for `ant`. |
| `registry-url` | `https://exist-db.org/exist/apps/public-repo` | A different expath registry. Short form - see the note below. |
| `extra-packages` | `""` | Newline-separated, ordered list of package QNames/abbrevs (e.g. `monex`, `functx`) that aren't a declared `<dependency>` but are still needed and are registry-published. Installed via `xst package install from-registry`, in list order, before the repo's own package. |
| `extra-xars-artifact` | `""` | Name of a GitHub Actions artifact - built and uploaded by a job in the *calling* workflow, not this one - containing pre-built `.xar` files to install via `xst package install local-files` before the repo's own package. For dependencies that aren't registry-published at all (have to be built from source). Install order follows filename sort order within the artifact, so name files accordingly (`01-Foo.xar`, `02-Bar.xar`) if it matters. |
| `shared-ref` | `main` | Pin to a specific ref of this repo instead of tracking `main`. |

**Registry URL note**: `xst package install from-registry` and `xst package install local-files --registry` expect *different* URL shapes against the same registry - confirmed empirically, not documented anywhere upstream. `registry-url` holds the short form (what `from-registry` needs as-is); `local-files` calls inside `install-smoke.yml` append `/public` themselves.

**Deliberately not supported**: an arbitrary pre-install script hook for building dependencies from source. `extra-xars-artifact` covers that need - the calling workflow's own job builds whatever it needs however it needs to and hands over the result as an artifact - without this workflow having to know anything about how it was built.
