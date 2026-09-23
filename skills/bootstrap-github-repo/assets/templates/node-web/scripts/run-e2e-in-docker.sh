#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"

playwright_version=$(node -e '
  const pkg = require("./package.json");
  const version = pkg.devDependencies?.["@playwright/test"] ?? pkg.dependencies?.["@playwright/test"];
  if (!/^[0-9]+\.[0-9]+\.[0-9]+$/.test(version ?? "")) {
    console.error("@playwright/test must use an exact release version in package.json");
    process.exit(1);
  }
  process.stdout.write(version);
')

playwright_image="mcr.microsoft.com/playwright:v${playwright_version}-noble"

exec docker run \
  --rm \
  --init \
  --ipc=host \
  --platform linux/amd64 \
  --env CI \
  --volume "$project_dir:/work" \
  --tmpfs /work/node_modules:exec \
  --workdir /work \
  "$playwright_image" \
  bash ./scripts/run-playwright-in-container.sh \
  "$@"
