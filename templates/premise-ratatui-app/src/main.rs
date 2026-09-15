mod ui;

use anyhow::Result;
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use std::io;

/// One terminal state that must be undone during cleanup.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CleanupStep {
    LeaveAlternateScreen,
    DisableRawMode,
}

/// Returns the cleanup steps required to restore `raw_mode` and
/// `alternate_screen`, in the order they must run. Only the states that were
/// actually initialized are cleaned up, so a partial init failure does not
/// leave the terminal in raw mode or on the alternate screen.
fn cleanup_steps(raw_mode: bool, alternate_screen: bool) -> Vec<CleanupStep> {
    let mut steps = Vec::new();
    if alternate_screen {
        steps.push(CleanupStep::LeaveAlternateScreen);
    }
    if raw_mode {
        steps.push(CleanupStep::DisableRawMode);
    }
    steps
}

/// Runs every requested cleanup step, reporting the first failure without
/// skipping any later step.
fn restore_terminal(raw_mode: bool, alternate_screen: bool) -> Result<()> {
    let mut first_error = None;
    for step in cleanup_steps(raw_mode, alternate_screen) {
        let outcome = match step {
            CleanupStep::LeaveAlternateScreen => {
                crossterm::execute!(io::stdout(), crossterm::terminal::LeaveAlternateScreen)
            }
            CleanupStep::DisableRawMode => crossterm::terminal::disable_raw_mode(),
        };
        if let Err(e) = outcome {
            if first_error.is_none() {
                first_error = Some(e);
            }
        }
    }
    if let Some(e) = first_error {
        Err(e.into())
    } else {
        Ok(())
    }
}

fn main() -> Result<()> {
    // Track which init steps succeed so cleanup restores exactly those states,
    // even when a later init step fails or the app returns early.
    let mut raw_mode = false;
    let mut alternate_screen = false;

    let result = (|| -> Result<()> {
        crossterm::terminal::enable_raw_mode()?;
        raw_mode = true;

        crossterm::execute!(io::stdout(), crossterm::terminal::EnterAlternateScreen)?;
        alternate_screen = true;

        let backend = CrosstermBackend::new(io::stdout());
        let mut terminal = Terminal::new(backend)?;
        ui::run(&mut terminal)
    })();

    // Always clean up whatever was initialized, on both success and error.
    let cleanup = restore_terminal(raw_mode, alternate_screen);

    result.and(cleanup)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cleanup_steps_cover_every_initialized_state() {
        assert!(cleanup_steps(false, false).is_empty());
        assert_eq!(
            cleanup_steps(true, false),
            vec![CleanupStep::DisableRawMode]
        );
        assert_eq!(
            cleanup_steps(true, true),
            vec![
                CleanupStep::LeaveAlternateScreen,
                CleanupStep::DisableRawMode
            ]
        );
    }
}
