# Scripts

Repo automation. **Read this index before writing a new script.** If you will
run a command again — this session or a later one — put it in `Scripts/` and
add a row here. Do not reinvent a pipeline in chat.

Swift (`swift Scripts/file.swift`) preferred. Bash only as a thin wrapper
around CLIs (`xcodebuild`, `swiftlint`, `swiftformat`, `gh`). Never Python.

When you add a script:

1. One file, one job. Name it after the job (`fetch-foo.swift`, not `util.sh`).
2. `.sh` files are `chmod +x` and run as `./Scripts/name.sh`.
3. `.swift` files run as `swift Scripts/name.swift`.
4. Add a one-line row to the table below in the same change.

| Script | What it does |
|---|---|
| `ci.sh` | Session gate: lint + format-check + tests + issues. `--fix` formats first. Same file GitHub Actions runs. |
| `lint.sh` | SwiftLint `--strict`, then SwiftFormat `--lint`. |
| `format.sh` | SwiftFormat in place (Airbnb). Called from `ci.sh --fix`. |
| `test.sh` | `swift test --parallel`, then `ariakit --help` / `--version`. |
| `libaria2.sh` | Build libaria2 1.37.0 (pinned sha256) into `.deps/libaria2` or `--prefix`. No-op if built or on Linux. |
| `env.sh` | `source` it: puts `.deps/libaria2` on `PKG_CONFIG_PATH`. |
| `issues.sh` | `swift build` with warnings-as-errors, then `print-issues.swift --swift-log`. |
| `print-issues.swift` | Parse xcresult JSON or a Swift diagnostic log. Exit 1 if errors/warnings. GitHub `::error` annotations. |
| `post-edit-lint.swift` | Claude PostToolUse hook: SwiftLint the edited `.swift` file. Always exits 0. |
| `doctor.sh` | Toolchain sanity: `swift`, SwiftLint, SwiftFormat. |
