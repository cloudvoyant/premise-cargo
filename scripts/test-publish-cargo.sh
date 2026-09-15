#!/usr/bin/env bash
# Validate release guards, four-package version synchronization, and restoration
# without contacting crates.io.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
publisher="$repo_root/scripts/publish-cargo.sh"
packages="premise-rust-lib premise-rust-app premise-clap-cli premise-ratatui-app"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/premise-cargo-publish-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

snapshot() {
	local destination="$1" pkg
	mkdir -p "$destination"
	for pkg in $packages; do
		cp "$repo_root/templates/$pkg/Cargo.toml" "$destination/$pkg.Cargo.toml"
	done
	cp "$repo_root/templates/Cargo.lock" "$destination/Cargo.lock"
}

assert_restored() {
	local expected="$1" pkg
	for pkg in $packages; do
		cmp "$expected/$pkg.Cargo.toml" "$repo_root/templates/$pkg/Cargo.toml"
	done
	cmp "$expected/Cargo.lock" "$repo_root/templates/Cargo.lock"
}

if "$publisher" rc 1.2.3 >/dev/null 2>&1; then
	echo "error: rc guard accepted a stable version" >&2
	exit 1
fi
if "$publisher" stable 1.2.3-rc.1 >/dev/null 2>&1; then
	echo "error: stable guard accepted a prerelease version" >&2
	exit 1
fi

snapshot "$tmp/before"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/mise" <<'FAKE_MISE'
#!/usr/bin/env bash
set -euo pipefail
version="$(sed -n 's/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' Cargo.toml | head -n1)"
printf '%s %s\n' "$(basename "$PWD")" "$version" >>"$PUBLISH_TEST_LOG"
if [ "${PUBLISH_TEST_FAIL_PACKAGE:-}" = "$(basename "$PWD")" ]; then
	exit 42
fi
FAKE_MISE
chmod +x "$tmp/bin/mise"

PUBLISH_TEST_LOG="$tmp/success.log" \
	PREMISE_TEMPLATE_TEST=1 \
	PATH="$tmp/bin:$PATH" \
	"$publisher" rc 1.2.3-rc.7 >/dev/null
assert_restored "$tmp/before"
for pkg in $packages; do
	grep -Fx "$pkg 1.2.3-rc.7" "$tmp/success.log" >/dev/null
done
[ "$(wc -l <"$tmp/success.log" | tr -d ' ')" = "4" ]

if PUBLISH_TEST_LOG="$tmp/failure.log" \
	PUBLISH_TEST_FAIL_PACKAGE="premise-clap-cli" \
	PREMISE_TEMPLATE_TEST=1 \
	PATH="$tmp/bin:$PATH" \
	"$publisher" stable 2.0.0 >/dev/null 2>&1; then
	echo "error: simulated publication failure unexpectedly succeeded" >&2
	exit 1
fi
assert_restored "$tmp/before"

echo "publish-cargo contract valid"
