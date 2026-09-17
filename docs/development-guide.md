# premise-cargo Development Guide

## Prerequisites

- [Premise](https://github.com/cloudvoyant/premise) — owns registry, CI, version, and release policy
- [Mise](https://mise.jdx.dev/) — installs the declared Rust tools
- Network access to crates.io

No Rust toolchain needs to be installed by hand. Mise reads `templates/mise.toml` and installs Rust 1.88 with rustfmt, Clippy, and rust-analyzer, plus Zig and cargo-zigbuild for release archives.

## Getting Started

```bash
pm template ls
pm ci flow on-commit --release none
```

The flow runs the root `on-commit` override. That override validates registry structure, runs every template contract through `pm template test`, checks formatting and lint, and never uploads a package without the `[publish-rc]` marker on a non-main push.

## Project Structure

```text
premise.yaml             # template-registry manifest and template declarations
mise.toml                # root CI overrides and coordinated package tasks
templates/mise.toml      # shared Rust toolchain and Cargo workspace tasks
templates/*/             # standalone source templates
.github/workflows/       # thin Premise action callers
docs/                    # development documentation
```

The root is a template registry, not a monorepo. Every source template has its own `Cargo.toml` and `mise.toml`. Template package versions remain `0.1.0` in source; calculated release versions exist only in disposable CI checkouts.

## Development Workflow

1. Edit one or more templates under `templates/`.
2. Run `pm ci flow on-commit --release none`.
3. Check registry formatting with `mise fmt --check`.
4. Inspect the generated release matrix with `pm release snapshot` when release configuration changes.

To work directly at the shared Cargo workspace:

```bash
cd templates
mise install
mise run build
mise run test
mise run format:check
mise run lint
```

Each template implements the required `install` task with `cargo fetch`. Premise runs that task after Mise tool setup. A generated standalone project creates its own lockfile on first install. Generated-project tool propagation remains tracked separately in DIFF-149.

## CI Flows

The workflows contain checkout plus the Premise action. The action sets up Mise, builds the pinned Premise revision, and invokes one flow:

- `on-commit` validates pull requests and unmarked feature pushes.
- A non-main push whose HEAD contains `[publish-rc]` runs the same `on-commit` flow with the crates.io token. The flow validates first and then invokes the root `publish:rc` task. Pull requests and unmarked pushes receive an empty token and never enter publication.
- `on-merge` validates the registry and complete Rust archive matrix, then prepares the stable tag, publishes GitHub archives, and publishes crates in one Premise-owned flow.
- `on-release` runs manual stage or production deployment conventions.

Root `on-commit` and `on-merge` Mise tasks override lifecycle fallback behavior. Guarded RC and stable publication remain owned by `pm ci flow` after the override completes.

## Publishing

### Versioning

Premise calculates versions with the svu Go SDK from the repository's stable `vMAJOR.MINOR.PATCH` tags. A `v0.0.0` bootstrap tag must exist before CI runs. The repository does not contain `.svu.yml` or `.goreleaser.yml`.

All four crates move together. RC versions use `MAJOR.MINOR.PATCH-rc.<github run number>` without a Git tag. Stable releases use strict `vMAJOR.MINOR.PATCH` repository tags.

### Package Tasks

The root publication task temporarily synchronizes all four `Cargo.toml` files and `Cargo.lock`, then invokes `publish:rc` or `publish` inside each template. Each package task checks crates.io and skips an existing crate/version pair before calling Cargo. A trap restores every source version after success, failure, or interruption.

`pm template test` sets `PREMISE_TEMPLATE_TEST=1`. In test mode, `publish:setup` skips token validation and each package publication task runs `cargo publish --dry-run --allow-dirty`. No package, tag, or release is created.

### GitHub Archives

GoReleaser builds archives for `premise-rust-app`, `premise-clap-cli`, and `premise-ratatui-app` for Linux and macOS on x86_64 and aarch64. `premise-rust-lib` publishes only to crates.io. Premise generates temporary GoReleaser configuration and removes it after the run.

### Credentials

Configure the protected `crates-io` GitHub environment with required reviewers. Store the restricted crates.io token as `CRATES_TOKEN`. The on-commit workflow maps it to `CARGO_REGISTRY_TOKEN` only for a marked push; pull requests and unmarked pushes receive an empty value.

Premise removes package credentials from the GoReleaser subprocess and removes GitHub credentials from the Cargo publication subprocess. Tokens are never printed or persisted. OIDC trusted publishing remains deferred under DIFF-152.
