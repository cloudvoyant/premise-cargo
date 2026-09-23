#!/usr/bin/env sh
set -eu

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
resolver="$root/scripts/resolve-stable-release.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

new_repository() {
  path="$1"
  git init -q "$path"
  git -C "$path" config user.name "Premise Test"
  git -C "$path" config user.email "premise-test@example.invalid"
  printf 'fixture\n' > "$path/fixture.txt"
  git -C "$path" add fixture.txt
  git -C "$path" commit -qm "test: create fixture"
}

zero="$tmp/zero"
new_repository "$zero"
(
  cd "$zero"
  "$resolver" "$tmp/zero.out"
)
printf 'version=\nshould_publish=false\n' > "$tmp/zero.expected"
cmp "$tmp/zero.expected" "$tmp/zero.out"

one="$tmp/one"
new_repository "$one"
git -C "$one" tag v1.2.3
git -C "$one" tag not-a-release
(
  cd "$one"
  "$resolver" "$tmp/one.out"
)
printf 'version=1.2.3\nshould_publish=true\n' > "$tmp/one.expected"
cmp "$tmp/one.expected" "$tmp/one.out"

two="$tmp/two"
new_repository "$two"
git -C "$two" tag v1.2.3
git -C "$two" tag v2.0.0
if (
  cd "$two"
  "$resolver" "$tmp/two.out" 2> "$tmp/two.err"
); then
  echo "error: multiple stable tags unexpectedly succeeded" >&2
  exit 1
fi
printf 'error: multiple stable release tags point at HEAD\n' > "$tmp/two.expected"
cmp "$tmp/two.expected" "$tmp/two.err"
[ ! -s "$tmp/two.out" ]

echo "stable release resolver tests passed"
