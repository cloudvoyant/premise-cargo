# premise-cargo

A Rust/Cargo template registry for [Premise](https://github.com/cloudvoyant/premise). Developers pick one of four minimal, publishable Rust templates from the normal Premise template picker, alongside the existing Go templates.

## Templates

| Template              | Kind | Description                                                                               |
| --------------------- | ---- | ----------------------------------------------------------------------------------------- |
| `premise-rust-lib`    | lib  | A Rust library that exports `hello_premise()` with a unit test.                           |
| `premise-rust-app`    | app  | A binary that delegates to an internal module and prints `hello premise-app!`.            |
| `premise-clap-cli`    | app  | A minimal Clap-derived CLI that prints `hello premise-clap-cli!`.                         |
| `premise-ratatui-app` | app  | A Ratatui terminal app that renders `hello premise-ratatui` centered and exits on Ctrl-C. |

Every template is a standalone Cargo package: its `Cargo.toml` is self-contained (no workspace inheritance), so a generated project builds outside this registry. Shared Rust tooling (`rust` with the `rustfmt`, `clippy`, and `rust-analyzer` components, plus `cargo-zigbuild`/`zig` for cross-compilation) lives only at `templates/mise.toml`; the repository root `mise.toml` performs no Rust build, format, or lint operations and installs no release tools. Premise owns version and release tooling.

## Requirements

- `pm` on `PATH` to list, generate, and validate templates.
- Network access to the public Cargo registry source.

No Rust toolchain needs to be installed by hand for registry validation or development. Premise runs template tasks through Mise, which loads `templates/mise.toml` and auto-installs its declared tools when a task first needs them. `pm install` remains the owner of the install lifecycle, so the registry does not define a separate install task.

The shared Rust toolchain is declared only at `templates/mise.toml` (the Cargo workspace root) and is inherited by each source template through Mise's parent-config merge. Each template's `mise.toml` carries tasks only and declares no `[tools]`. Premise does not yet copy the shared `[tools]` block into generated projects, so generated-project tool propagation remains separate follow-up work.

## Generate a project

```bash
pm generate
```

Choose `premise-rust-lib`, `premise-rust-app`, `premise-clap-cli`, or `premise-ratatui-app`. The generated project contains its own `mise.toml` copied from the template.

## Validate the registry

Build `pm` from `cloudvoyant/premise`, then run at this repository root:

```bash
pm template test
```

This runs every required Premise contract task for every declared template. In template-test mode (`PREMISE_TEMPLATE_TEST=1`), the publication tasks are safe no-ops: `publish:setup` skips the crates.io token preflight, and `publish:rc`/`publish` run `cargo publish --dry-run --allow-dirty` only, so nothing is ever uploaded and no Git tag is created.

## Develop the templates

The Cargo workspace root is `templates/`. Mise provisions the declared Rust toolchain automatically on first use, so no separate install step is required:

```bash
cd templates
mise run build
mise run test
mise run format:check
mise run lint
```

## Publishing

### This registry

This repository is the template registry, delivered as source by merging to `main`. Consumers read templates from the git-backed registry. In addition, the four packages under `templates/` publish together to crates.io, and GoReleaser attaches stable GitHub release binaries for the three application packages.

### Versioning

Release versions are calculated by Premise through the svu Go SDK from a `v0.0.0` stable bootstrap tag that is created externally before CI runs. Premise restricts calculation to stable SemVer tags (`vMAJOR.MINOR.PATCH`) and ignores unrelated tags. No `.svu.yml` file or svu executable is required. Calculated versions are applied only to the disposable CI checkout and are never committed.

### Release candidates

RC publication is opt-in: a feature-branch push whose HEAD commit message contains the exact marker `[publish-rc]` publishes real RC crates. The version is `MAJOR.MINOR.PATCH-rc.<github run number>` (untagged). Pull requests validate only and never receive publish credentials.

### Stable releases

On pushes to `main`, the on-merge workflow validates the trunk and runs `pm release prepare`, `pm release github`, and `pm release packages` in separate credential-bearing steps. Premise reuses or creates the stable tag, generates temporary GoReleaser configuration, publishes GitHub artifacts, and then invokes the registry's Cargo publication task:

- GoReleaser builds the three application binaries (`premise-rust-app`, `premise-clap-cli`, `premise-ratatui-app`) for Linux/macOS x86_64/aarch64 and attaches the archives and checksums to the GitHub release. `premise-rust-lib` is left out of the binary builds and publishes only to crates.io. The repository does not carry `.goreleaser.yml`.
- The shared publication script synchronizes all four crate versions and Cargo.lock, then publishes each crate/version pair that does not already exist on crates.io.

Both publication paths are rerun-safe: GoReleaser replaces conflicting GitHub release assets, and already-published crate/version pairs are skipped. The shared script restores all transient `Cargo.toml` and `Cargo.lock` edits on success, failure, or interruption.

### crates.io token

Publication is token-based. Restrict the `CRATES_TOKEN` organization secret to this repository and to a crates.io token that can publish only these four crates. Configure the `crates-io-rc` and `crates-io` GitHub environments with required reviewers. GitHub and Cargo publication run in separate steps, so GoReleaser never receives the crates.io token. Premise also removes GitHub credentials before invoking the Cargo publication task and strips package credentials from GoReleaser defensively. Tokens are never printed or persisted. Credential-free `pm template test` performs full Cargo dry-run verification first, and the credential-bearing step uses Cargo's `--no-verify` mode. `publish:setup` is a token-based preflight that verifies `CARGO_REGISTRY_TOKEN` is present without exposing it:

```bash
CARGO_REGISTRY_TOKEN=<token> mise run publish:setup
```

An OIDC migration to crates.io trusted publishing is deferred to Linear DIFF-152.

### Test mode

Under `pm template test` (or `PREMISE_TEMPLATE_TEST=1`), the publication tasks are safe no-ops:

- `publish:setup` prints that the crates.io token preflight is skipped.
- `publish:rc` and `publish` run `cargo publish --dry-run --allow-dirty` only, so the working tree can be validated before commit without uploading a crate.

## License

[MIT](LICENSE)
