# premise-cargo

The official Rust/Cargo template registry for [Premise](https://github.com/cloudvoyant/premise). Developers pick one of four minimal, publishable Rust templates from the normal Premise template picker, alongside the existing Go templates.

## Templates

| Template | Kind | Description |
| --- | --- | --- |
| `premise-rust-lib` | lib | A Rust library that exports `hello_premise()` with a unit test. |
| `premise-rust-app` | app | A binary that delegates to an internal module and prints `hello premise-app!`. |
| `premise-clap-cli` | app | A minimal Clap-derived CLI that prints `hello premise-clap-cli!`. |
| `premise-ratatui-app` | app | A Ratatui terminal app that renders `hello premise-ratatui` centered and exits on Ctrl-C. |

Every template is a standalone Cargo package: its `Cargo.toml` is self-contained (no workspace inheritance), so a generated project builds outside this registry. Shared Rust tooling (`rust` with the `rustfmt` and `clippy` components) lives only at `templates/mise.toml`; the repository root `mise.toml` performs no Rust build, format, or lint operations and installs no Rust toolchain.

## Requirements

- A current Rust toolchain with `cargo`, `rustfmt`, and `clippy` (the generated `mise.toml` installs and activates them).
- `pm` on `PATH` to list, generate, and validate templates.
- Network access to the public Cargo registry source.

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

The Cargo workspace root is `templates/`:

```bash
cd templates
mise run build
mise run test
mise run format:check
mise run lint
```

## Publishing

Each template's `publish:rc` and `publish` tasks share one Cargo publish path and differ only in their version guard: `publish:rc` requires a SemVer prerelease package version, and `publish` requires a stable version. Neither task changes Git state or creates a tag. Release workflows use the configured crates.io trusted publisher through GitHub Actions OIDC.

## License

[MIT](LICENSE)
