#!/usr/bin/env bash
set -euo pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd "$test_dir/.." && pwd)
template_dir="$project_dir/skills/bootstrap-github-repo/assets/templates/node-web"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

ruby - "$template_dir" <<'RUBY'
require "yaml"

template_dir = ARGV.fetch(0)
workflow = YAML.safe_load(File.read("#{template_dir}/.github/workflows/ci.yml"))
jobs = workflow.fetch("jobs")
raise "required job names changed" unless jobs.keys.sort == %w[build e2e]
raise "Knip is missing from build" unless jobs.fetch("build").fetch("steps").any? { |step| step["run"] == "npm run knip" }
e2e = jobs.fetch("e2e")
raise "E2E must use the same npm script locally and in CI" unless e2e.fetch("steps").any? { |step| step["run"] == "npm run test:e2e" }
raise "E2E must not pin a separate job container" if e2e.key?("container")

dependabot = YAML.safe_load(File.read("#{template_dir}/.github/dependabot.yml"))
npm = dependabot.fetch("updates").find { |entry| entry["package-ecosystem"] == "npm" }
raise "npm Dependabot config is missing" unless npm
group = npm.fetch("groups").fetch("dependencies")
raise "Playwright must be excluded from grouped updates" unless group.fetch("exclude-patterns").include?("@playwright/test")
RUBY

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/scripts" "$fixture_dir/fake-bin"
cp "$template_dir"/scripts/*.sh "$fixture_dir/scripts/"

cat >"$fixture_dir/package.json" <<'JSON'
{
  "private": true,
  "scripts": {
    "test:e2e": "bash ./scripts/run-e2e-in-docker.sh",
    "knip": "knip"
  },
  "devDependencies": {
    "@playwright/test": "1.63.0",
    "knip": "6.38.0"
  }
}
JSON

cat >"$fixture_dir/fake-bin/docker" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$DOCKER_ARGS_LOG"
printf '%s' "${CI-unset}" >"$DOCKER_CI_LOG"
SH
cat >"$fixture_dir/fake-bin/knip" <<'SH'
#!/usr/bin/env bash
printf 'called' >"$KNIP_LOG"
SH
chmod +x "$fixture_dir/fake-bin/docker" "$fixture_dir/fake-bin/knip"

(
  cd "$fixture_dir"
  env -u CI PATH="$fixture_dir/fake-bin:$PATH" \
    DOCKER_ARGS_LOG="$fixture_dir/local-args" DOCKER_CI_LOG="$fixture_dir/local-ci" \
    npm run test:e2e >/dev/null
  CI=true PATH="$fixture_dir/fake-bin:$PATH" \
    DOCKER_ARGS_LOG="$fixture_dir/ci-args" DOCKER_CI_LOG="$fixture_dir/ci-ci" \
    npm run test:e2e >/dev/null
  PATH="$fixture_dir/fake-bin:$PATH" KNIP_LOG="$fixture_dir/knip-log" \
    npm run knip >/dev/null
)

cmp "$fixture_dir/local-args" "$fixture_dir/ci-args" || fail "local and CI E2E commands differ"
[[ "$(<"$fixture_dir/local-ci")" == "unset" ]] || fail "local E2E unexpectedly sets CI"
[[ "$(<"$fixture_dir/ci-ci")" == "true" ]] || fail "CI was not forwarded to Docker"
[[ "$(<"$fixture_dir/knip-log")" == "called" ]] || fail "Knip script did not run"
grep -q '^mcr\.microsoft\.com/playwright:v1\.63\.0-noble$' "$fixture_dir/local-args" || fail "Docker image does not match @playwright/test"

sed 's/"1.63.0"/"^1.63.0"/' "$fixture_dir/package.json" >"$fixture_dir/package.json.new"
mv "$fixture_dir/package.json.new" "$fixture_dir/package.json"
if (
  cd "$fixture_dir"
  PATH="$fixture_dir/fake-bin:$PATH" DOCKER_ARGS_LOG="$fixture_dir/invalid-args" \
    DOCKER_CI_LOG="$fixture_dir/invalid-ci" npm run test:e2e >/dev/null 2>&1
); then
  fail "non-exact Playwright version was accepted"
fi
[[ ! -f "$fixture_dir/invalid-args" ]] || fail "Docker started with an invalid Playwright version"

echo "Node Web template tests passed."
