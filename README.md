# premise-cargo

A Rust/Cargo template registry for [Premise](https://github.com/cloudvoyant/premise). Developers pick one of four minimal, publishable Rust templates from the normal Premise template picker, alongside the existing Go templates.

## Templates

| Template              | Kind | Description                                                                               |
| --------------------- | ---- | ----------------------------------------------------------------------------------------- |
| `premise-rust-lib`    | lib  | A Rust library that exports `hello_premise()` with a unit test.                           |
| `premise-rust-app`    | app  | A binary that delegates to an internal module and prints `hello premise-app!`.            |
| `premise-clap-cli`    | app  | A minimal Clap-derived CLI that prints `hello premise-clap-cli!`.                         |
| `premise-ratatui-app` | app  | A Ratatui terminal app that renders `hello premise-ratatui` centered and exits on Ctrl-C. |

Every template is a standalone Cargo package: its `Cargo.toml` is self-contained (no workspace inheritance), so a generated project builds outside this registry. Shared Rust tooling (`rust` with the `rustfmt`, `clippy`, and `rust-analyzer` components) lives only at `templates/mise.toml`; the repository root `mise.toml` performs no Rust build, format, or lint operations and installs no Rust toolchain.

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

This runs every required Premise contract task for every declared template. In template-test mode (`PREMISE_TEMPLATE_TEST=1`), publication tasks run `cargo publish --dry-run` only and never upload a crate or create a Git tag.

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

This repository is the registry, delivered as source and published by merging to `main`. The `on-merge.yml` workflow re-runs the same pinned Premise source-build feature flow as `on-commit.yml` on the trunk, keeping `pm template test` authoritative. Consumers read templates straight from the git-backed registry. The template placeholder crates are not published to crates.io, and there is no automated registry release/versioning here.

### A generated crate

Publishing a generated project happens through that project's own `publish:rc` and `publish` tasks. They share one Cargo publish path and differ only in their version guard: `publish:rc` requires a SemVer prerelease package version, and `publish` requires a stable version. Neither task changes Git state or creates a tag. Under `pm template test`, both tasks run with `PREMISE_TEMPLATE_TEST=1` and perform `cargo publish --dry-run --allow-dirty` only, so the current template working tree can be validated before commit without uploading a crate. A real publication is done from the generated project's own repository through its configured crates.io trusted publisher via GitHub Actions OIDC.

## License

[MIT](LICENSE)
