#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_FILE" >&2
  exit 2
fi

output_file="$1"
tags="$(git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
count="$(printf '%s\n' "$tags" | sed '/^$/d' | wc -l | tr -d ' ')"

case "$count" in
  0)
    printf 'version=\nshould_publish=false\n' >> "$output_file"
    ;;
  1)
    printf 'version=%s\nshould_publish=true\n' "${tags#v}" >> "$output_file"
    ;;
  *)
    echo "error: multiple stable release tags point at HEAD" >&2
    exit 1
    ;;
esac
