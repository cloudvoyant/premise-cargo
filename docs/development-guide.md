# premise-cargo Development Guide

## Prerequisites

- [Premise](https://github.com/cloudvoyant/premise) — owns registry, CI, version, and release policy
- [Mise](https://mise.jdx.dev/) — installs the declared Rust tools
- Network access to crates.io

No Rust toolchain needs to be installed by hand. The root and generated-client Mise configurations install Rust 1.88 with rustfmt, Clippy, and rust-analyzer, plus Zig and cargo-zigbuild for release archives. The Tauri template also declares its Debian/Ubuntu WebKit and desktop libraries through Mise bootstrap packages. Its `install` task applies them automatically on apt-based hosts before fetching Cargo dependencies; macOS and Windows skip only that apt step.

## Getting Started

```bash
pm template ls
pm ci flow on-commit --release none
```

The flow uses Premise's default template-registry lifecycle. It enters each declared template, installs Mise tools, runs the template `install` task, and then runs the commit lifecycle. It never uploads a package without the `[publish-rc]` marker on a non-main push.

## Project Structure

```text
premise.yaml             # registry declarations and workspace-file allowlist
Cargo.toml               # aggregate source and release workspace
Cargo.lock               # aggregate source dependency lock
mise.toml                # registry development tasks and release toolchain
.gitignore               # declared generated-client root policy
templates/*/             # standalone source templates, tools, and contracts
.github/workflows/       # thin Premise action callers
docs/                    # development documentation
```

The root is a template registry and an aggregate Cargo workspace used for source validation and coordinated releases. It is not a Premise monorepo. Every source template has its own `mise.toml` and Cargo package metadata, including the Rust toolchain needed after generation. The Tauri package is nested at `src-tauri/Cargo.toml`; the other four package manifests are direct. Only repository-root files declared by `template_registry.workspace_files` become client-root inputs; the selected package lands under `apps/<name>` or `libs/<name>`. The aggregate root `Cargo.toml` and `Cargo.lock` remain registry-only. Template package versions remain `0.1.0` in source; calculated release versions exist only in disposable CI checkouts. Tauri stable publication supplies the release version as transient build configuration and does not rewrite the source manifest.

## Development Workflow

1. Edit one or more templates under `templates/`.
2. Run `pm ci flow on-commit --release none`.
3. Check registry formatting with `mise fmt --check`.
4. Inspect the generated release matrix with `pm release snapshot` when release configuration changes.

Each template implements the required `install` task. The four direct Cargo templates use `cargo fetch`. The Tauri template first runs `mise bootstrap packages apply --manager apt` when `apt-get` is available, then fetches its nested Cargo dependencies. Premise runs `install` after Mise tool setup and validates each template contract independently. To work directly on one template, change into its directory and run its contract tasks:

```bash
cd templates/premise-rust-lib
mise install
mise run build
mise run test
mise run format:check
mise run lint
```

A generated package creates its own lockfile when used without a client-root Cargo workspace. Generated-project tool propagation remains tracked separately in DIFF-149.

## CI Flows

The workflows contain checkout plus the Premise action. The action sets up Mise, builds the pinned Premise revision, and invokes one flow:

- `on-commit` validates pull requests and unmarked feature pushes.
- A non-main push whose HEAD contains `[publish-rc]` runs the same `on-commit` flow with the crates.io token. The flow validates first and then delegates coordinated publication to Premise's Cargo extension, which invokes each template's `publish:rc` task. Pull requests and unmarked pushes run without a Cargo token and never enter publication.
- `on-merge` runs the default template-registry lifecycle, then prepares the stable tag, builds the complete Rust archive matrix, publishes GitHub archives, and publishes crates in one Premise-owned flow. After that release job finds exactly one strict stable tag at the checked-out commit, a native Tauri matrix runs on Ubuntu 22.04, macOS 14, and Windows 2022. A commit with no stable tag skips the matrix; a rerun reuses the same tag and safely replaces installer assets.
- `on-release` runs manual stage or production deployment conventions.

The registry intentionally does not define root `on-commit` or `on-merge` overrides. Premise's default template-registry flow owns lifecycle orchestration, guarded RC publication, and stable publication.

## Publishing

### Versioning

Premise calculates versions with the svu Go SDK from the repository's stable `vMAJOR.MINOR.PATCH` tags. A `v0.0.0` bootstrap tag must exist before CI runs. The repository does not contain `.svu.yml` or `.goreleaser.yml`.

All four crates move together. RC versions use `MAJOR.MINOR.PATCH-rc.<github run number>` without a Git tag. Stable releases use strict `vMAJOR.MINOR.PATCH` repository tags.

### Package Tasks

Premise's Cargo publication coordinator temporarily synchronizes all four package manifests and the root `Cargo.lock`, then invokes `publish:rc` or `publish` inside each template. Before it skips an existing crate/version pair, Premise verifies that the authenticated crates.io user owns the crate. Premise restores every source version and the root lock after success or failure; each template task only validates its release kind and calls Cargo.

`pm template test` sets `PREMISE_TEMPLATE_TEST=1`. In test mode, each package publication task runs `cargo publish --dry-run --allow-dirty`. No package, tag, or release is created.

### GitHub Archives

GoReleaser builds archives for `premise-rust-app`, `premise-clap-cli`, and `premise-ratatui-app` for Linux and macOS on x86_64 and aarch64. `premise-rust-lib` publishes only to crates.io. Premise generates temporary GoReleaser configuration and removes it after the run.

The Tauri template does not enter Cargo registry or generic GoReleaser publication because its package is nested and declares `publish = false`. Its own stable `mise run publish` task builds only the current platform's installable bundles and uploads them to the existing `v$RELEASE_VERSION` GitHub Release with `gh release upload --clobber`. Premise remains responsible for release intent and the prepared GitHub Release; the repository workflow invokes the public template task once per native runner. If Premise skips stable publication, no native jobs run. If the workflow reruns for an existing stable tag, the same jobs safely replace assets with matching names. `mise run publish:rc` is an explicit successful no-op. A generated Tauri project supports `install`, `build`, `clean`, `test`, `lint`, `lint:fix`, `format`, `format:check`, `env-pull`, `publish:rc`, `publish`, `run`, `dev`, `deploy`, and `e2e`. It contains only the committed HTML/CSS placeholder; connecting another frontend is deferred.

### Credentials

Configure the protected `crates-io` and `crates-io-rc` GitHub environments with required reviewers. Store the restricted crates.io token as `CRATES_TOKEN` in both environments. Only the marked-push job enters `crates-io-rc` and maps the secret to `CARGO_REGISTRY_TOKEN`; pull requests and unmarked pushes run a separate job with no Cargo credential.

Premise removes package credentials from the GoReleaser subprocess and removes GitHub credentials from the Cargo publication subprocess. Tokens are never printed or persisted. OIDC trusted publishing remains deferred under DIFF-152.
