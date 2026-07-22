# GitHub repository defaults (proof of concept)

Personal repositories often share the same GitHub settings even when their
application stacks differ. This repository keeps those settings as code and
applies them with a small `gh`-based command.

The command is safe by default: without `--apply`, it only prints the planned
changes.

```console
./bin/repo-bootstrap hiroto7/example --profile python
./bin/repo-bootstrap hiroto7/example --profile python --apply
```

## Profiles

| Profile | Required checks | Intended use |
| --- | --- | --- |
| `python` | `test` | Ubuntu Python services and command-line tools |
| `python-macos` | `test (macos-latest)`, `test (ubuntu-latest)`, `package-macos` | Python applications packaged for macOS |
| `node-web` | `build`, `e2e` | Node web applications with Playwright |
| `tooling` | `test` | Shell-based repository tooling |

Each profile has a starter `.github` directory under [`templates/`](templates/).
Install those files in a new repository before applying the matching ruleset.
The proof of concept deliberately does not commit or push files into another
repository.

## What `--apply` changes

- enables squash merging and disables merge commits and rebase merging;
- deletes head branches automatically after merge;
- creates or updates the profile's `standard-main` repository ruleset;
- for `python-macos`, also creates or updates the `release-tags` ruleset.

The main ruleset prevents deletion and force-pushes, requires linear and signed
history, requires pull requests with resolved review threads, and requires the
profile's GitHub Actions checks. It requires no approving reviews, which keeps
the workflow practical for a personal repository.

Rulesets are upserted by name and target, so rerunning the same profile updates
the existing managed ruleset instead of creating duplicates. Unrelated
rulesets are left untouched.

## Requirements and limitations

- `gh`, authenticated with repository administration access;
- `jq`;
- a repository with its initial files already pushed;
- repository rulesets must be available for the repository's visibility and
  GitHub plan.

The bundled workflow files are starters, not universal build definitions.
Application-specific packaging and E2E commands should remain in the
application repository.

## Verification

```console
./tests/test_repo_bootstrap.sh
```
