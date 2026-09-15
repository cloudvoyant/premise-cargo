#!/usr/bin/env bash
# Publish all four crates at one version, idempotently.
#
# Usage: scripts/publish-cargo.sh <channel> <version>
#
#   channel  rc | stable
#   version  Cargo version (no leading "v"), e.g. 0.1.0 or 0.1.0-rc.5
#
# Responsibilities:
#   1. Validate channel semantics (rc -> prerelease, stable -> no prerelease).
#   2. Transiently synchronize all four package versions and Cargo.lock.
#   3. Skip crate/version pairs that already exist on crates.io.
#   4. Publish without re-running package build scripts after credential-free
#      `pm template test` has verified all package archives.
#
# The script never commits, tags, or pushes, and never prints or persists
# CARGO_REGISTRY_TOKEN (or CRATES_TOKEN).
set -euo pipefail

channel="${1:-}"
version="${2:-}"
version="${version#v}"

case "$channel" in
rc)
	case "$version" in
	*-*) ;;
	*)
		echo "error: rc channel requires a prerelease version (got \"$version\")" >&2
		exit 1
		;;
	esac
	task="publish:rc"
	;;
stable)
	case "$version" in
	*-*)
		echo "error: stable channel requires a stable version (got \"$version\")" >&2
		exit 1
		;;
	esac
	task="publish"
	;;
*)
	echo "error: unknown channel \"$channel\" (want rc | stable)" >&2
	exit 1
	;;
esac

if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
	echo "error: invalid version \"$version\"" >&2
	exit 1
fi

packages="premise-rust-lib premise-rust-app premise-clap-cli premise-ratatui-app"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
templates="$repo_root/templates"

# Back up every tracked file modified below. Restore them on success, failure,
# or interruption so local runs cannot leave calculated release versions in
# the source tree.
backup_dir="$(mktemp -d "${TMPDIR:-/tmp}/premise-cargo-publish.XXXXXX")"
for pkg in $packages; do
	cp "$templates/$pkg/Cargo.toml" "$backup_dir/$pkg.Cargo.toml"
done
cp "$templates/Cargo.lock" "$backup_dir/Cargo.lock"

restore_versions() {
	status=$?
	trap - EXIT
	set +e
	for pkg in $packages; do
		cp "$backup_dir/$pkg.Cargo.toml" "$templates/$pkg/Cargo.toml"
	done
	cp "$backup_dir/Cargo.lock" "$templates/Cargo.lock"
	rm -rf "$backup_dir"
	exit "$status"
}
trap restore_versions EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Transiently synchronize all four package versions and Cargo.lock. The changes
# exist only while this script runs; `cargo publish --allow-dirty` packages them
# before the EXIT trap restores the original files.
(
	cd "$templates"
	for pkg in $packages; do
		sed -i.bak "s/^version = \"[^\"]*\"/version = \"$version\"/" "$pkg/Cargo.toml"
		rm -f "$pkg/Cargo.toml.bak"
	done
	awk -v ver="$version" -v names="$packages" '
		BEGIN { split(names, pkgs, " ") }
		{
			in_pkg = 0
			for (i in pkgs) {
				if ($0 == "name = \"" pkgs[i] "\"") { in_pkg = 1 }
			}
		}
		in_pkg { print; pending = 1; next }
		pending && /^version = "/ {
			sub(/^version = "[^"]*"/, "version = \"" ver "\"")
			print
			pending = 0
			next
		}
		{ print }
	' Cargo.lock >Cargo.lock.tmp
	mv Cargo.lock.tmp Cargo.lock
)

crate_version_exists() {
	local name="$1" ver="$2" code
	code="$(curl -sS -o /dev/null -w '%{http_code}' \
		-A "premise-release-check" \
		"https://crates.io/api/v1/crates/${name}/${ver}" 2>/dev/null || true)"
	[ "$code" = "200" ]
}

for pkg in $packages; do
	if [ "${PREMISE_TEMPLATE_TEST:-}" = "1" ]; then
		echo "publish (test mode): skipping crates.io existence check for $pkg"
		echo "publish: $pkg $version"
		(
			cd "$templates/$pkg"
			mise run "$task"
		)
		continue
	fi
	if crate_version_exists "$pkg" "$version"; then
		echo "skip: $pkg $version already published"
		continue
	fi
	echo "publish: $pkg $version"
	(
		cd "$templates/$pkg"
		cargo publish --allow-dirty --no-verify
	)
done
