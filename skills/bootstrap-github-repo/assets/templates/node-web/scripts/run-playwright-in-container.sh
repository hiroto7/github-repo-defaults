#!/usr/bin/env bash
set -euo pipefail

npm ci
exec ./node_modules/.bin/playwright test "$@"
