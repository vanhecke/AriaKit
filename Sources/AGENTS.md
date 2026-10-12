# Sources

Public API surface.

- Every public declaration has a DocC summary (sentence fragment, ends with a
  period).
- No SwiftUI, AppKit, or UIKit in this target — Linux CI compiles it.
- Do not introduce MainActor isolation at the module level.
