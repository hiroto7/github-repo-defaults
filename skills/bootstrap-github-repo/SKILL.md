---
name: bootstrap-github-repo
description: Set up or standardize a GitHub repository with profile-based GitHub Actions, Dependabot, squash-only merge settings, and repository rulesets. Use when Codex is asked to create a new repository with the usual GitHub configuration, apply the same CI and branch strategy across repositories, or bring an existing repository in line with these defaults. Do not use for an ordinary CI failure or a one-off workflow edit.
---

# Bootstrap GitHub Repository

Apply repository defaults without overwriting application-specific behavior. Keep the bundled script deterministic and use judgment only for profile selection and template adaptation.

## Workflow

1. Resolve the exact `OWNER/REPO`, local checkout, default branch, visibility, and requested publication scope.
2. Inspect existing `.github` files, package manifests, test commands, repository merge settings, and rulesets. Treat existing configuration as user-owned.
3. Select one profile:
   - `python`: Ubuntu Python service or CLI; requires `test`.
   - `python-macos`: Python application packaged for macOS; requires both OS test jobs and `package-macos`.
   - `node-web`: Node.js web application with Playwright; requires `build` and `e2e`.
   - `tooling`: shell-based repository tooling; requires `test`.
4. Compare `assets/templates/<profile>/.github` with the target. Copy only the needed files and adapt application names, versions, package commands, E2E commands, and packaging steps. Preserve relevant existing jobs and permissions.
5. Run the target repository's local checks. Commit and publish through its normal branch and PR workflow when requested.
6. Confirm that GitHub Actions has run successfully and that its check names exactly match the selected profile.
7. Run `bash scripts/repo-bootstrap OWNER/REPO --profile PROFILE` and report the dry-run plan.
8. Run the same command with `--apply` only when the target, profile, and remote settings mutation are authorized.
9. Re-fetch repository merge settings, rulesets, and required status checks. Report any unsupported rule caused by repository visibility or GitHub plan.

## Safety Rules

- Never apply rulesets before the initial workflow and required checks exist.
- Never silently replace an existing workflow, Dependabot configuration, or semantically equivalent ruleset.
- Keep `--apply` explicit. Do not infer permission to modify GitHub settings from a request that only asks for analysis or a dry run.
- Do not commit tokens, credentials, local absolute paths, or machine-specific installation state.
- Keep action references pinned to full commit SHAs and retain readable version comments.
- After creating or updating a PR, confirm that CI passes.

## Bundled Resources

- Run `bash scripts/repo-bootstrap` for dry-run and repository settings application. Do not rely on its executable bit because archive-based Skill installation may not preserve file modes.
- Copy and adapt starter files from `assets/templates/<profile>/.github`.
- Treat `assets/rulesets/*.json` as script inputs; do not edit a target repository to store them unless explicitly requested.
