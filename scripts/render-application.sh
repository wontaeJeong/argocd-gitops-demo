#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: REPO_URL=<git-url> $0 <template> <output>" >&2
  exit 1
fi

if [ -z "${REPO_URL:-}" ]; then
  echo "ERROR: REPO_URL is required" >&2
  exit 1
fi

template="$1"
output="$2"

if [ ! -f "$template" ]; then
  echo "ERROR: template not found: $template" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
placeholder="\${REPO_URL}"
content=$(<"$template")
printf '%s\n' "${content//$placeholder/$REPO_URL}" > "$output"
echo "Rendered $output"
