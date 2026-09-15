/// Returns the greeting printed by the application.
pub fn message() -> &'static str {
    "hello premise-app!"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn message_returns_greeting() {
        assert_eq!(message(), "hello premise-app!");
    }
}
