#!/usr/bin/env swift
// Claude Code PostToolUse hook: lint a just-edited Swift file.
// Reads hook JSON from stdin. Always exits 0 (lint findings are informational).
//
//   swift Scripts/post-edit-lint.swift

import Foundation

let input = (try? FileHandle.standardInput.readToEnd()) ?? Data()
guard
  let obj = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
  let toolInput = obj["tool_input"] as? [String: Any],
  let path = toolInput["file_path"] as? String,
  path.hasSuffix(".swift"),
  !URL(fileURLWithPath: path).pathComponents.contains("Scripts")
else {
  exit(0)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["swiftlint", "lint", "--quiet", "--strict", "--", path]
process.standardInput = FileHandle.nullDevice
do {
  try process.run()
  process.waitUntilExit()
} catch {
  // Missing swiftlint must not fail the hook.
}

exit(0)
