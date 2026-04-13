#!/usr/bin/env sh
set -eu

if [ "$#" -gt 1 ]; then
  echo "Usage: scripts/commitlint.sh [<from>..<to>]" >&2
  exit 2
fi

RANGE="${1:-HEAD~1..HEAD}"
FROM=${RANGE%%..*}
TO=${RANGE##*..}

if [ -z "$FROM" ] || [ -z "$TO" ] || [ "$FROM" = "$TO" ]; then
  echo "Invalid range '$RANGE'. Expected <from>..<to>." >&2
  exit 2
fi

npx commitlint --from "$FROM" --to "$TO" --verbose
