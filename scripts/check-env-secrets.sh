#!/bin/sh
# Blocks a commit whose staged changes contain a secret value from the local .env
set -eu
cd "$(dirname "$0")/.."
[ -f .env ] || exit 0

values=$(mktemp)
trap 'rm -f "$values"' EXIT
grep -E '^[A-Z_]*(PASSWD|PASSWORD|SECRET|KEY|TOKEN|USER|ADDRESSES|HOSTS)=' .env |
  cut -d= -f2- | sed 's/^"//; s/"$//' | awk 'length >= 6' >"$values" || true
[ -s "$values" ] || exit 0

if git diff --cached -U0 --no-color | grep '^+' | grep -qF -f "$values"; then
  echo "staged changes contain a secret value from .env" >&2
  exit 1
fi
