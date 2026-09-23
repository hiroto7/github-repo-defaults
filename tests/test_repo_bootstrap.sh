#!/usr/bin/env bash
set -euo pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd "$test_dir/.." && pwd)
skill_dir="$project_dir/skills/bootstrap-github-repo"
command_path="$skill_dir/scripts/repo-bootstrap"
wrapper_path="$project_dir/bin/repo-bootstrap"

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
bash -n "$wrapper_path"
bash -n "$project_dir/tests/test_repo_bootstrap.sh"
bash -n "$project_dir/tests/test_node_web_template.sh"
bash -n "$project_dir/tests/fixtures/gh"
bash -n "$skill_dir/assets/templates/node-web/scripts/run-e2e-in-docker.sh"
bash -n "$skill_dir/assets/templates/node-web/scripts/run-playwright-in-container.sh"

for ruleset_file in "$skill_dir"/assets/rulesets/*.json; do
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
  "$skill_dir"/agents/openai.yaml \
  "$skill_dir"/assets/templates/*/.github/workflows/*.yml \
  "$skill_dir"/assets/templates/*/.github/dependabot.yml

ruby -e '
  require "yaml"
  files = Dir.glob("#{ARGV.fetch(0)}/assets/templates/*/.github/workflows/*.yml")
  files.each do |file|
    File.readlines(file).each do |line|
      next unless line.include?("- uses:")
      raise "action is not pinned to a full SHA: #{file}: #{line}" unless line.match?(/- uses: [^@\s]+@[0-9a-f]{40} # v\S+/)
    end
  end

  macos = YAML.safe_load(File.read("#{ARGV.fetch(0)}/assets/templates/python-macos/.github/workflows/ci.yml"))
  raise "macOS workflow must be read-only by default" unless macos.fetch("permissions") == {"contents" => "read"}
  release = macos.fetch("jobs").fetch("release")
  raise "only the release job needs write access" unless release.fetch("permissions") == {"contents" => "write"}
' "$skill_dir"

ruby -e '
  require "yaml"
  skill_dir = ARGV.fetch(0)
  skill_text = File.read(File.join(skill_dir, "SKILL.md"))
  frontmatter = skill_text.match(/\A---\n(.*?)\n---\n/m) or raise "missing skill frontmatter"
  metadata = YAML.safe_load(frontmatter[1])
  raise "unexpected skill frontmatter" unless metadata.keys.sort == %w[description name]
  raise "unexpected skill name" unless metadata["name"] == "bootstrap-github-repo"

  agent_metadata = YAML.safe_load(File.read(File.join(skill_dir, "agents/openai.yaml")))
  default_prompt = agent_metadata.dig("interface", "default_prompt")
  raise "default prompt must mention the skill" unless default_prompt.include?("$bootstrap-github-repo")
' "$skill_dir"

if grep -R -n -E '\[TODO|TODO:' "$skill_dir"; then
  fail "skill contains an unresolved TODO"
fi

python_plan=$(bash "$command_path" hiroto7/example --profile python)
assert_contains "$python_plan" "Mode:       dry-run"
assert_contains "$python_plan" "standard-main [branch]: test"
assert_contains "$python_plan" "No changes made"

macos_plan=$(bash "$command_path" hiroto7/example --profile python-macos)
assert_contains "$macos_plan" "test (macos-latest), test (ubuntu-latest), package-macos"
assert_contains "$macos_plan" "release-tags [tag]: no status checks"

node_plan=$(bash "$command_path" hiroto7/example --profile node-web)
assert_contains "$node_plan" "standard-main [branch]: build, e2e"
assert_contains "$node_plan" "assets/templates/node-web/scripts"

tooling_plan=$(bash "$command_path" hiroto7/example --profile tooling)
assert_contains "$tooling_plan" "standard-main [branch]: test"
assert_contains "$tooling_plan" "assets/templates/tooling/.github"

wrapper_plan=$("$wrapper_path" hiroto7/example --profile python)
assert_contains "$wrapper_plan" "standard-main [branch]: test"

if bash "$command_path" invalid --profile python >/dev/null 2>&1; then
  fail "invalid repository name was accepted"
fi

fake_dir="$project_dir/tests/fixtures"
fake_log=$(mktemp)
trap 'rm -f "$fake_log"' EXIT

PATH="$fake_dir:$PATH" FAKE_GH_LOG="$fake_log" \
  bash "$command_path" hiroto7/example --profile python --apply >/dev/null

apply_log=$(<"$fake_log")
assert_contains "$apply_log" "api --method PATCH repos/hiroto7/example"
assert_contains "$apply_log" "api --method POST repos/hiroto7/example/rulesets"

: >"$fake_log"
PATH="$fake_dir:$PATH" FAKE_GH_LOG="$fake_log" FAKE_RULESET_ID=12345 \
  bash "$command_path" hiroto7/example --profile node-web --apply >/dev/null

update_log=$(<"$fake_log")
assert_contains "$update_log" "api --method PUT repos/hiroto7/example/rulesets/12345"

bash "$project_dir/tests/test_node_web_template.sh"

echo "All tests passed."
