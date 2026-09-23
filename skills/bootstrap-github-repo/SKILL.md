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
4. Compare `assets/templates/<profile>/.github` with the target. Copy only the needed files and adapt application names, versions, package commands, E2E commands, and packaging steps. Preserve relevant existing jobs and permissions. For `node-web`, also copy `assets/templates/node-web/scripts/` and complete the Node setup below.
5. Run the target repository's local checks. Commit and publish through its normal branch and PR workflow when requested.
6. Confirm that GitHub Actions has run successfully and that its check names exactly match the selected profile.
7. Run `bash scripts/repo-bootstrap OWNER/REPO --profile PROFILE` and report the dry-run plan.
8. Run the same command with `--apply` only when the target, profile, and remote settings mutation are authorized.
9. Re-fetch repository merge settings, rulesets, and required status checks. Report any unsupported rule caused by repository visibility or GitHub plan.

## Node Web Setup

The `node-web` profile is a complete CI starting point, not just a workflow file. Set up the target application so every command in the template does real work before requiring `build` and `e2e` checks.

- Use npm with a committed `package-lock.json` and working `build`, `typecheck`, `lint:ci`, and `test` scripts. Add application-specific checks to the `build` job when needed.
- Add `@playwright/test` as an exact dev dependency, a Playwright config, and at least one meaningful browser test. Set `test:e2e` to `bash ./scripts/run-e2e-in-docker.sh`. Use this same command locally and in CI; Docker must be available in both places. The runner derives the official `v<package version>-noble` image from `package.json` and installs locked dependencies inside it. Confirm that the matching image exists when updating Playwright.
- Add Knip as a dev dependency and a `knip` script. Run type generation before Knip if the framework needs generated types. Configure only application-specific entry points that Knip cannot discover; do not add broad exclusions to make the check pass.
- Keep `@playwright/test` outside the grouped npm minor/patch updates so that its image and test results are reviewed in a separate Dependabot PR.
- Keep the `build` and `e2e` job names used by the ruleset. Adapt the commands and tests, not these required check names.

## Safety Rules

- Never apply rulesets before the initial workflow and required checks exist.
- Never silently replace an existing workflow, Dependabot configuration, or semantically equivalent ruleset.
- Keep `--apply` explicit. Do not infer permission to modify GitHub settings from a request that only asks for analysis or a dry run.
- Do not commit tokens, credentials, local absolute paths, or machine-specific installation state.
- Keep action references pinned to full commit SHAs and retain readable version comments.
- Keep workflow permissions at `contents: read` unless a specific job needs more; only the macOS release job needs `contents: write`.
- After creating or updating a PR, confirm that CI passes.

## Maintenance Feedback Loop

Treat problems found during real use as evidence and classify them before changing this Skill.

- Finish the target repository task with the smallest safe workaround when possible.
- Classify the finding as target-specific, a reproducible general defect, a feature proposal, or a security concern.
- Do not change this Skill for target-specific behavior.
- Never treat an edit to the installed local copy as the permanent fix. Use `hiroto7/github-repo-defaults` as the canonical source.
- For a reproducible general defect, when the authenticated GitHub user owns the canonical source repository, create a separate branch and Draft PR with a regression test. Keep it separate from the target repository's branch and PR.
- When the authenticated user does not own the canonical source repository, report the defect and proposed fix without opening a PR.
- For a feature proposal or behavior change, explain the need and obtain confirmation before implementation.
- For a security concern, report it privately before exposing details in a public issue or PR.
- Confirm the maintenance PR's CI. Never merge it without explicit user authorization.

## Bundled Resources

- Run `bash scripts/repo-bootstrap` for dry-run and repository settings application. Do not rely on its executable bit because archive-based Skill installation may not preserve file modes.
- Copy and adapt starter files from `assets/templates/<profile>/.github`.
- For `node-web`, also copy the two `assets/templates/node-web/scripts/` runners and wire `test:e2e` to them.
- Treat `assets/rulesets/*.json` as script inputs; do not edit a target repository to store them unless explicitly requested.
