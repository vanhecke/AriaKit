# AGENTS.md — AriaKit

Swift bindings to libaria2 and a live terminal downloader built on them.

Swift 6 SPM library (`AriaKit`) wrapping libaria2 through Swift C++ interop, plus
the `ariakit` command-line tool. Not MainActor-by-default. GPL-2.0-or-later
because it links libaria2.

This file is the contract for every coding agent. `CLAUDE.md` imports it.
Nested `AGENTS.md` files apply to their directory. MCP config is `.mcp.json`.

## Non-negotiable

- NEVER add an `.xcodeproj` to git. Open `Package.swift` in Xcode if you need an IDE.
- NEVER hit a live network from a test.
- NEVER default this module onto MainActor. Mark UI-facing types `@MainActor`
  explicitly if they ever appear.
- NEVER add Python. Scripts are `swift file.swift` (preferred) or bash.
- NEVER call libaria2 off the session thread. All calls go through
  `AriaSession`'s mailbox; one session per process.
- NEVER leak C++ types into AriaKit's public API. libaria2 access goes through
  `Sources/AriaShim` free functions.
- Tool: errors and usage to stderr, data to stdout. Exit 0 on success, 64 on
  usage (`EX_USAGE`).

## How to work

Bias toward caution over speed. For a one-line fix, use judgment.

- **Don't assume.** State assumptions. If the request has more than one reading,
  present them — do not pick silently. If a simpler approach exists, say so and
  push back. If something is unclear, stop, name it, and ask.
- **Minimum code.** Solve what was asked. No speculative features, no abstraction
  for a single call site, no configurability that was not requested, no error
  handling for impossible cases. If 200 lines could be 50, rewrite it.
- **Surgical diffs.** Touch only what the request requires. Do not "improve"
  adjacent code, comments, or formatting. Do not refactor what is not broken.
  Match existing style. Mention unrelated dead code; do not delete it unless
  asked. Remove imports, variables, and helpers *your* change made unused.
  Every changed line should trace to the request.
- **Verify in a loop.** Restate the task as a checkable goal, then loop until it
  holds. "Add validation" → tests for invalid inputs, then make them pass.
  "Fix the bug" → a failing test that reproduces it, then make it pass.
  "Refactor X" → `./Scripts/ci.sh` green before and after. Done means
  `./Scripts/ci.sh` prints `CI OK`. "Make it work" is not a success criterion.

## Practices

- SPM only. No CocoaPods, no Carthage. Prefer Apple packages, then SSWG, then
  nothing. Networking is `URLSession`, never Alamofire.
- Configuration: `apple/swift-configuration` (`ConfigReader`).
- Swift 6 language mode + **complete** concurrency checking. Do not fight the
  checker with `@unchecked Sendable` / `nonisolated(unsafe)` — fix isolation.
  `// justification:` required if an escape is unavoidable.
- App targets: approachable concurrency, MainActor-by-default, no redundant
  `@MainActor`. CLI/web: not MainActor-by-default.
- `async`/`await` and structured concurrency. No new Combine. No callback hell.
- Prefer `struct` unless you need a class (`@Model`, Fluent `Model`, ObjC).
- Names follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
  Layout and lint follow [Airbnb Swift](https://github.com/airbnb/swift) via
  SwiftFormat + SwiftLint (`./Scripts/lint.sh`). 2-space indent.
- DocC `///` on every public declaration.
- Swift Testing, not XCTest (except XCUITest).
- Force-unwraps and IUO are errors. Optional chaining only when ownership of
  the nil case is clear.
- Scripts are Swift (`swift path/to/file.swift`) or bash. Never Python. Prefer
  Swift. Bash only as a thin wrapper around CLIs (`xcodebuild`, `swiftlint`,
  `swiftformat`). Do not add `.py` files or invoke `python`/`python3`.
- **Do not reinvent scripts.** Read `Scripts/AGENTS.md` first. If you will run
  a command more than once, add `Scripts/<name>.swift` (preferred) or
  `Scripts/<name>.sh` and a one-line row in that index in the same change.
- After every agent session: `./Scripts/ci.sh` must print `CI OK`. That is
  lint + format-check + tests + issues. Same command GitHub Actions runs.
- Hot path? Instruments (Time Profiler / Allocations / Swift Concurrency) or
  `xcrun xctrace` before calling it done.

## MCP and Xcode issues

Servers are declared in `.mcp.json` (mirrored in `opencode.json` and
`.grok/config.toml`). Prefer them over raw `xcodebuild` / `swift test` / a web
search when connected. If a server is missing, use the Commands table — do not
stop. Tool names and session defaults: `AGENTS.mcp.md`.

When the `xcode` MCP is connected, call `XcodeListNavigatorIssues` after edits
and **fix what it reports** on files you touched. Re-query until clean.

When MCP is missing, or in CI: `./Scripts/issues.sh` (GUI can pass
`--from-bundle build/AriaKit.xcresult`). That is the Issue navigator
equivalent from a result bundle / `swift build` log. GitHub Actions prints
file annotations. A green test run with a non-empty issues dump is not done.


## Commands

- **After a coding session:** `./Scripts/ci.sh` (same script as GitHub Actions)
- Script index: `Scripts/AGENTS.md`. Read it before writing a new script; add a
  row if you will reuse the command.
- Fast loop: `source Scripts/env.sh && swift test --parallel`
- libaria2 (macOS): `./Scripts/libaria2.sh` builds it into `.deps/libaria2`;
  `Scripts/env.sh` puts it on `PKG_CONFIG_PATH`. Linux: `apt install libaria2-0-dev`.
- `swift run ariakit --help` / `--version`

## Layout

| Path | Holds |
|---|---|
| `Sources/Clibaria2` | System library: `pkg-config libaria2`. |
| `Sources/AriaShim` | C++ shim over `aria2.h`: free functions, no virtual classes for Swift. |
| `Sources/AriaKit` | Library. `AriaSession` owns the libaria2 thread. Public API has DocC summaries. |
| `Sources/AriaKitCLI` | `ariakit` tool: ArgumentParser command, live TUI / piped REPL. |
| `Tests/AriaKitTests` | Swift Testing. Session tests use loopback only and stay serialized. |
| `Tests/AriaKitCLITests` | Swift Testing for parsing, formatting, config. |
| `Scripts/AGENTS.md` | Index of repo scripts. Add a row when you add a script. |

## Architecture

- Follow Swift API Design Guidelines: clarity at the point of use, documentation
  comments on every public declaration, methods named by side-effects.
- One primary type per file; filename == type name.
- Upcoming: `ExistentialAny`, `NonisolatedNonsendingByDefault`.
- C++ interop (`.interoperabilityMode(.Cxx)`) is required in every module that
  imports AriaKit, including downstream packages.
- `print` is a lint error.

## Definition of Done

- [ ] `./Scripts/ci.sh` prints `CI OK` (required after every agent session)
- [ ] New public type has a test and a summary doc comment
- [ ] Linux job is meaningful: no UIKit/AppKit in the library target
- [ ] `--help` / `--version` still work
