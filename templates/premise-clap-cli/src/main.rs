use clap::Parser;

/// A minimal Clap-derived command-line interface.
#[derive(Parser)]
#[command(version, about)]
struct Cli {}

/// Parse the given arguments and emit the greeting.
fn run(cli: Cli) -> anyhow::Result<()> {
    let _ = cli;
    println!("hello premise-clap-cli!");
    Ok(())
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    run(cli)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_representative_args() {
        let cli = Cli::parse_from(["premise-clap-cli"]);
        run(cli).unwrap();
    }
}
