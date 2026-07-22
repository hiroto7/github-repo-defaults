#!/usr/bin/env bash
set -euo pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd "$test_dir/.." && pwd)
command_path="$project_dir/bin/repo-bootstrap"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local actual=$1
  local expected=$2
  [[ "$actual" == *"$expected"* ]] || fail "expected output to contain: $expected"
}

bash -n "$command_path"
bash -n "$project_dir/tests/test_repo_bootstrap.sh"
bash -n "$project_dir/tests/fixtures/gh"

for ruleset_file in "$project_dir"/rulesets/*.json; do
  jq empty "$ruleset_file"
done

ruby -e '
  require "yaml"
  ARGV.each do |file_name|
    YAML.safe_load(
      File.read(file_name),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: true
    )
  end
' \
  "$project_dir"/.github/workflows/*.yml \
  "$project_dir"/.github/dependabot.yml \
  "$project_dir"/templates/*/.github/workflows/*.yml \
  "$project_dir"/templates/*/.github/dependabot.yml

python_plan=$("$command_path" hiroto7/example --profile python)
assert_contains "$python_plan" "Mode:       dry-run"
assert_contains "$python_plan" "standard-main [branch]: test"
assert_contains "$python_plan" "No changes made"

macos_plan=$("$command_path" hiroto7/example --profile python-macos)
assert_contains "$macos_plan" "test (macos-latest), test (ubuntu-latest), package-macos"
assert_contains "$macos_plan" "release-tags [tag]: no status checks"

node_plan=$("$command_path" hiroto7/example --profile node-web)
assert_contains "$node_plan" "standard-main [branch]: build, e2e"

tooling_plan=$("$command_path" hiroto7/example --profile tooling)
assert_contains "$tooling_plan" "standard-main [branch]: test"
assert_contains "$tooling_plan" "Starter files: templates/tooling/.github"

if "$command_path" invalid --profile python >/dev/null 2>&1; then
  fail "invalid repository name was accepted"
fi

fake_dir="$project_dir/tests/fixtures"
fake_log=$(mktemp)
trap 'rm -f "$fake_log"' EXIT

PATH="$fake_dir:$PATH" FAKE_GH_LOG="$fake_log" \
  "$command_path" hiroto7/example --profile python --apply >/dev/null

apply_log=$(<"$fake_log")
assert_contains "$apply_log" "api --method PATCH repos/hiroto7/example"
assert_contains "$apply_log" "api --method POST repos/hiroto7/example/rulesets"

: >"$fake_log"
PATH="$fake_dir:$PATH" FAKE_GH_LOG="$fake_log" FAKE_RULESET_ID=12345 \
  "$command_path" hiroto7/example --profile node-web --apply >/dev/null

update_log=$(<"$fake_log")
assert_contains "$update_log" "api --method PUT repos/hiroto7/example/rulesets/12345"

echo "All tests passed."
