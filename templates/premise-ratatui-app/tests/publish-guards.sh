#!/usr/bin/env bash
# Hermetic checks for the normal-mode publish version guards.
#
# `pm template test` only exercises the PREMISE_TEMPLATE_TEST=1 dry-run branch.
# These checks exercise the normal branch with package versions that MUST be
# rejected by the version guard before `cargo publish` (and therefore before any
# network access or Git mutation) runs. A stub `cargo`/`git` is prepended to
# PATH so that a regression that lets execution reach a real publish or tag
# fails loudly instead of touching the network or the repository.
set -eu

template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mise_bin="$(command -v mise)"
fake_bin="$(mktemp -d)"
work_dir="$(mktemp -d)"
out_file="$(mktemp)"

cleanup() {
  rm -rf "$fake_bin" "$work_dir" "$out_file"
}
trap cleanup EXIT

# Stubs that fail loudly if the guard lets execution reach them.
for cmd in cargo git; do
  cat > "$fake_bin/$cmd" <<STUB
#!/usr/bin/env bash
echo "error: unexpected $cmd invocation: \$*" >&2
exit 99
STUB
  chmod +x "$fake_bin/$cmd"
done

# Create an isolated template copy (under the system temp dir so no parent
# mise.toml with [tools] is inherited) with a stable or prerelease version.
make_project() {
  local name="$1"
  local version_kind="$2"
  mkdir -p "$work_dir/$name"
  cp "$template_dir/Cargo.toml" "$work_dir/$name/Cargo.toml"
  cp "$template_dir/mise.toml" "$work_dir/$name/mise.toml"
  if [ "$version_kind" = "prerelease" ]; then
    sed -i.bak 's/^\(version[[:space:]]*=[[:space:]]*"[^"]*\)"/\1-rc.1"/' \
      "$work_dir/$name/Cargo.toml"
    rm -f "$work_dir/$name/Cargo.toml.bak"
  fi
}

# Run one publish task in normal mode (PREMISE_TEMPLATE_TEST unset) with the
# stubs shadowing the real tools.
run_task() {
  local name="$1"
  local task="$2"
  (
    cd "$work_dir/$name"
    env -u PREMISE_TEMPLATE_TEST PATH="$fake_bin:$PATH" "$mise_bin" run "$task"
  )
}

# publish:rc must reject a stable package version.
make_project stable stable
if run_task stable "publish:rc" > "$out_file" 2>&1; then
  echo "FAIL: publish:rc accepted a stable version" >&2
  cat "$out_file" >&2
  exit 1
fi
grep -q "publish:rc requires a SemVer prerelease version" "$out_file"

# publish must reject a prerelease package version.
make_project prerelease prerelease
if run_task prerelease "publish" > "$out_file" 2>&1; then
  echo "FAIL: publish accepted a prerelease version" >&2
  cat "$out_file" >&2
  exit 1
fi
grep -q "publish requires a stable version" "$out_file"

echo "publish guards verified (normal mode)"
