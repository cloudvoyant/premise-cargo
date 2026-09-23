# premise-cargo

A Rust/Cargo template registry for [Premise](https://github.com/cloudvoyant/premise). Developers can select one of five minimal Rust templates alongside Premise's Go templates.

## Templates

| Template              | Kind | Description                                                                               |
| --------------------- | ---- | ----------------------------------------------------------------------------------------- |
| `premise-rust-lib`    | lib  | A Rust library that exports `hello_premise()` with a unit test.                           |
| `premise-rust-app`    | app  | A binary that delegates to an internal module and prints `hello premise-app!`.            |
| `premise-clap-cli`    | app  | A minimal Clap-derived CLI that prints `hello premise-clap-cli!`.                         |
| `premise-ratatui-app` | app  | A Ratatui terminal app that renders `hello premise-ratatui` centered and exits on Ctrl-C. |
| `premise-tauri-app`   | app  | A Tauri v2 desktop shell with a bundled HTML/CSS placeholder and native installers.       |

The first four templates are standalone Cargo packages. The Tauri template uses the conventional nested `src-tauri/` package layout. The repository-root `Cargo.toml` and `Cargo.lock` form the aggregate source and release workspace, but they are not copied into generated clients. `template_registry.workspace_files` declares `.gitignore` as the only shared client-root file. Each selected template owns its Rust tools, package metadata, and contract tasks under `apps/<name>` or `libs/<name>`.

## Requirements

- `pm` on `PATH` to list, generate, and validate templates.
- Network access to the public Cargo registry source.

Premise and Mise provision the Rust toolchain used for registry validation. No Rust toolchain needs to be installed by hand.

## Generate a project

```bash
pm generate
```

Choose `premise-rust-lib`, `premise-rust-app`, `premise-clap-cli`, `premise-ratatui-app`, or `premise-tauri-app`. The Tauri template asks `App name:` and `Bundle identifier:`, then generates a placeholder-only desktop shell. Connecting Svelte, TanStack, or another frontend is intentionally out of scope.

## Development

See the [development guide](docs/development-guide.md) for validation, CI flows, versioning, publication, and credential handling.

## License

[MIT](LICENSE)
