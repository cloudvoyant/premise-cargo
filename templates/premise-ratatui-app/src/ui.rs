use anyhow::Result;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::backend::CrosstermBackend;
use ratatui::layout::Rect;
use ratatui::widgets::Paragraph;
use ratatui::{Frame, Terminal};
use std::io::Stdout;
use std::time::Duration;

/// Renders the greeting centered in the available area.
pub fn ui(frame: &mut Frame) {
    let area = frame.area();
    let text = "hello premise-ratatui";
    let width = text.len() as u16;
    let x = area.x + area.width.saturating_sub(width) / 2;
    let y = area.y + area.height.saturating_sub(1) / 2;
    let rect = Rect::new(x, y, width, 1);
    frame.render_widget(Paragraph::new(text), rect);
}

/// Draws the greeting and waits for Ctrl-C before returning.
pub fn run(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> Result<()> {
    loop {
        terminal.draw(ui)?;
        if event::poll(Duration::from_millis(250))? {
            match event::read()? {
                Event::Key(key)
                    if key.kind == KeyEventKind::Press
                        && key.code == KeyCode::Char('c')
                        && key.modifiers.contains(KeyModifiers::CONTROL) =>
                {
                    return Ok(());
                }
                _ => {}
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::backend::TestBackend;

    #[test]
    fn renders_greeting_centered() {
        let width = 40u16;
        let height = 5u16;
        let backend = TestBackend::new(width, height);
        let mut terminal = Terminal::new(backend).unwrap();
        terminal.draw(ui).unwrap();

        let text = "hello premise-ratatui";
        let row = (height - 1) / 2;
        let left = (width - text.len() as u16) / 2;
        let right = width - left - text.len() as u16;

        let mut expected = vec![" ".repeat(width as usize); height as usize];
        expected[row as usize] = format!(
            "{}{}{}",
            " ".repeat(left as usize),
            text,
            " ".repeat(right as usize),
        );

        terminal.backend().assert_buffer_lines(expected);
    }
}
