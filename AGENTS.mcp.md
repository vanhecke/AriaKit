## MCP servers — prefer these over raw shell

Declared in `.mcp.json` (mirrored in `opencode.json` and `.grok/config.toml`).
Use them before `xcodebuild`, `swift test`, or a web search when connected.
Versions are pinned; never `@latest`.

**If a server is not in this session, use the Commands table.** Do not stop.
Do not invent tool names.

### `XcodeBuildMCP` — building, testing, running

**Call `session_show_defaults` once per session before your first build.**
Defaults: project `AriaKit.xcodeproj` (GUI) or package path `.` (cli/web),
scheme `AriaKit`, configuration `Debug`, arch `arm64`, bundle id
`n/a` (GUI), extra args `CODE_SIGNING_ALLOWED=NO`.
`session_set_defaults` so later calls need no arguments.

| Instead of | Use |
|---|---|
| `swift test --package-path Packages/X` | `swift_package_test` |
| `swift build --package-path Packages/X` | `swift_package_build` |
| `xcodebuild build …` (macOS) | `build_macos` |
| `xcodebuild test …` (macOS) | `test_macos` (skip `AriaKitUITests` unless `UITEST_RUNNER=host`) |
| `xcodebuild` (iOS) | `build_ios` / `test_sim` (ios-app; include UI tests) |
| coverage JSON by hand | `get_coverage_report` / `get_file_coverage` |

Failures come back as `diagnostics.errors` with the source line. **Fix those.**

UI-automation tools (`screenshot`, `tap`, `snapshot_ui`) are simulator-only.
macOS XCUITest uses `./Scripts/uitest.sh`.

### `xcode` — open IDE, docs, **and issues**

Needs a `tabIdentifier` from `XcodeListWindows`. The project must be open.

- **`XcodeListNavigatorIssues` is mandatory after you edit Swift or project
  files** when this server is connected. The issue list is the work list. Fix
  what you introduced; re-query until clean.
- **No MCP?** `./Scripts/issues.sh` — same errors/warnings from
  `xcresulttool get build-results` (GUI) or the `swift build` log (cli/web).
  CI runs this too. Live editor-only squiggles still need the MCP / open IDE.
- `DocumentationSearch` before a web search for SwiftUI / AppKit / UIKit.
- `RenderPreview` for a SwiftUI `#Preview`.
- `BuildProject`, `RunAllTests`, `RunSomeTests`, `GetBuildLog`, `GetTestList`.
- `XcodeGrep` / `XcodeRead` / `XcodeGlob` / `XcodeLS` skip `.build` noise.

### `apple-docs` — API reference and WWDC

- `search_framework_symbols`: `framework: "swiftui"`, `namePattern: "Table*"`.
- `search_apple_docs` wants **short API names**, not sentences.
- `get_apple_doc_content`, `get_platform_compatibility`,
  `search_wwdc_content` / `get_wwdc_code_examples`.
