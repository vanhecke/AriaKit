#!/usr/bin/env swift
// Print compiler issues as text (and GitHub Actions annotations).
//
//   swift Scripts/print-issues.swift --swift-log LOG
//     stdout+stderr from `swift build` / `swift test`
//
// Exit 1 if any error or warning is present.
// The IDE navigator is a superset (SourceKit live issues). This dump is
// what CI and agents get without the Xcode MCP.

import Foundation

func writeOut(_ line: String) {
  fputs(line + "\n", stdout)
  fflush(stdout)
}

func emit(
  severity: String,
  path: String,
  line: String,
  col: String,
  message: String,
) {
  var loc = path.isEmpty ? "<unknown>" : path
  if !line.isEmpty {
    loc += ":\(line)"
    if !col.isEmpty {
      loc += ":\(col)"
    }
  }
  let padded = severity.padding(toLength: 8, withPad: " ", startingAt: 0)
  writeOut("\(padded) \(loc)  \(message)")

  let onGitHub = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
  if onGitHub, !path.isEmpty, severity == "error" || severity == "warning" {
    var extra = line.isEmpty ? "" : ",line=\(line)"
    if !col.isEmpty {
      extra += ",col=\(col)"
    }
    writeOut("::\(severity) file=\(path)\(extra)::\(message)")
  }
}

// MARK: - swift build / test log

func parseSwiftDiagnostic(
  _ raw: String
) -> (file: String, line: String, col: String, sev: String, msg: String)? {
  let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  let markers = ["error", "warning", "note", "remark"]
  for sev in markers {
    let marker = ": \(sev): "
    guard let range = line.range(of: marker) else { continue }
    let loc = String(line[..<range.lowerBound])
    let msg = String(line[range.upperBound...])
    let parts = loc.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count >= 2, Int(parts[parts.count - 1]) != nil else { continue }
    if parts.count >= 3, Int(parts[parts.count - 2]) != nil {
      let col = parts[parts.count - 1]
      let lineNo = parts[parts.count - 2]
      let file = parts.dropLast(2).joined(separator: ":")
      return (file, lineNo, col, sev, msg)
    }
    let lineNo = parts[parts.count - 1]
    let file = parts.dropLast().joined(separator: ":")
    return (file, lineNo, "", sev, msg)
  }
  return nil
}

func fromSwiftLog(_ text: String) -> Int32 {
  var errors = 0
  var warnings = 0
  for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
    guard let diag = parseSwiftDiagnostic(String(raw)) else { continue }
    switch diag.sev {
    case "error":
      errors += 1
    case "warning":
      warnings += 1
    default:
      continue
    }
    emit(
      severity: diag.sev,
      path: diag.file,
      line: diag.line,
      col: diag.col,
      message: diag.msg,
    )
  }
  writeOut("swift log  errors=\(errors) warnings=\(warnings)")
  return (errors > 0 || warnings > 0) ? 1 : 0
}

// MARK: - CLI

func usage() -> Never {
  fputs(
    "usage: swift Scripts/print-issues.swift --swift-log LOG\n",
    stderr,
  )
  exit(2)
}

func readText(from path: String) -> String {
  let url = URL(fileURLWithPath: path)
  let data: Data
  do {
    data = try Data(contentsOf: url)
  } catch {
    fputs("print-issues.swift: cannot read \(path): \(error)\n", stderr)
    exit(2)
  }
  return String(decoding: data, as: UTF8.self)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args[0] == "-h" || args[0] == "--help" {
  usage()
}

guard args.count == 2, args[0] == "--swift-log" else { usage() }
exit(fromSwiftLog(readText(from: args[1])))
