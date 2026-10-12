# Sources

- `Command.swift` is `AsyncParsableCommand`. Do not hand-roll argv.
- `AppConfig` is `ConfigReader`, not `ProcessInfo.processInfo`.
- FileHandle for I/O when not using ArgumentParser's built-in help/version.
- Subprocess (if the package is present) instead of Foundation `Process`.
