# premise-cargo

A Rust/Cargo template registry for [Premise](https://github.com/cloudvoyant/premise). Developers can select one of four minimal, publishable Rust templates alongside Premise's Go templates.

## Templates

| Template              | Kind | Description                                                                               |
| --------------------- | ---- | ----------------------------------------------------------------------------------------- |
| `premise-rust-lib`    | lib  | A Rust library that exports `hello_premise()` with a unit test.                           |
| `premise-rust-app`    | app  | A binary that delegates to an internal module and prints `hello premise-app!`.            |
| `premise-clap-cli`    | app  | A minimal Clap-derived CLI that prints `hello premise-clap-cli!`.                         |
| `premise-ratatui-app` | app  | A Ratatui terminal app that renders `hello premise-ratatui` centered and exits on Ctrl-C. |

Every template is a standalone Cargo package. Shared registry tooling lives at `templates/mise.toml`; each template keeps the task contract copied into generated projects.

## Requirements

- `pm` on `PATH` to list, generate, and validate templates.
- Network access to the public Cargo registry source.

Premise and Mise provision the Rust toolchain used for registry validation. No Rust toolchain needs to be installed by hand.

## Generate a project

```bash
pm generate
```

Choose `premise-rust-lib`, `premise-rust-app`, `premise-clap-cli`, or `premise-ratatui-app`.

## Development

See the [development guide](docs/development-guide.md) for validation, CI flows, versioning, publication, and credential handling.

## License

[MIT](LICENSE)
