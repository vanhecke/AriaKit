#!/usr/bin/env swift
// Print compiler/analyzer issues as text (and GitHub Actions annotations).
//
//   swift Scripts/print-issues.swift --xcresult JSON
//     JSON from `xcresulttool get build-results --path … --compact`
//   swift Scripts/print-issues.swift --swift-log LOG
//     stdout+stderr from `swift build` / `swift test`
//
// Exit 1 if any error, warning, or analyzer warning is present.
// The IDE navigator is a superset (SourceKit live issues). This dump is
// what CI and agents get without the Xcode MCP.

import Foundation

func writeOut(_ line: String) {
  fputs(line + "\n", stdout)
  fflush(stdout)
}

// MARK: - Source locations

func parseSourceURL(_ url: String?) -> (path: String, line: String, col: String) {
  guard var raw = url, !raw.isEmpty else {
    return ("", "", "")
  }
  if raw.hasPrefix("file://") {
    raw.removeFirst("file://".count)
  }
  let parts = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
  let encodedPath = String(parts[0])
  let path = encodedPath.removingPercentEncoding ?? encodedPath
  var line = ""
  var col = ""
  if parts.count > 1 {
    for fragment in parts[1].split(separator: "&") {
      let kv = fragment.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      guard kv.count == 2 else { continue }
      switch kv[0] {
      case "StartingLineNumber":
        line = String(kv[1])
      case "StartingColumnNumber":
        col = String(kv[1])
      default:
        break
      }
    }
  }
  return (path, line, col)
}

func emit(
  severity: String,
  path: String,
  line: String,
  col: String,
  message: String,
  target: String = "",
) {
  var loc = path.isEmpty ? "<unknown>" : path
  if !line.isEmpty {
    loc += ":\(line)"
    if !col.isEmpty {
      loc += ":\(col)"
    }
  }
  let prefix = target.isEmpty ? "" : "\(target) "
  let padded = severity.padding(toLength: 8, withPad: " ", startingAt: 0)
  writeOut("\(padded) \(prefix)\(loc)  \(message)")

  let onGitHub = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
  if onGitHub, !path.isEmpty, severity == "error" || severity == "warning" {
    var extra = line.isEmpty ? "" : ",line=\(line)"
    if !col.isEmpty {
      extra += ",col=\(col)"
    }
    writeOut("::\(severity) file=\(path)\(extra)::\(message)")
  }
}

// MARK: - xcresult JSON

func jsonInt(_ value: Any?) -> Int? {
  if let i = value as? Int {
    return i
  }
  if let n = value as? NSNumber {
    return n.intValue
  }
  return nil
}

func issueDicts(_ data: [String: Any], key: String) -> [[String: Any]] {
  data[key] as? [[String: Any]] ?? []
}

func count(in data: [String: Any], countKey: String, arrayKey: String) -> Int {
  if let n = jsonInt(data[countKey]) {
    return n
  }
  return issueDicts(data, key: arrayKey).count
}

func fromXcresult(_ data: [String: Any]) -> Int32 {
  let errorCount = count(in: data, countKey: "errorCount", arrayKey: "errors")
  let warningCount = count(in: data, countKey: "warningCount", arrayKey: "warnings")
  let analyzerCount = count(in: data, countKey: "analyzerWarningCount", arrayKey: "analyzerWarnings")
  let status = data["status"] as? String ?? "?"
  writeOut(
    "build \(status)  errors=\(errorCount) warnings=\(warningCount) analyzer=\(analyzerCount)"
  )

  let groups: [(severity: String, key: String, analyzer: Bool)] = [
    ("error", "errors", false),
    ("warning", "warnings", false),
    ("warning", "analyzerWarnings", true),
  ]
  for group in groups {
    for issue in issueDicts(data, key: group.key) {
      let loc = parseSourceURL(issue["sourceURL"] as? String)
      var msg = issue["message"] as? String ?? ""
      if group.analyzer {
        msg = "[analyzer] \(msg)"
      }
      emit(
        severity: group.severity,
        path: loc.path,
        line: loc.line,
        col: loc.col,
        message: msg,
        target: issue["targetName"] as? String ?? "",
      )
    }
  }
  return (errorCount > 0 || warningCount > 0 || analyzerCount > 0) ? 1 : 0
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
    "usage: swift Scripts/print-issues.swift --xcresult JSON | --swift-log LOG\n",
    stderr,
  )
  exit(2)
}

func readJSONObject(from path: String) -> [String: Any] {
  let url = URL(fileURLWithPath: path)
  let data: Data
  do {
    data = try Data(contentsOf: url)
  } catch {
    fputs("print-issues.swift: cannot read \(path): \(error)\n", stderr)
    exit(2)
  }
  let obj: Any
  do {
    obj = try JSONSerialization.jsonObject(with: data)
  } catch {
    fputs("print-issues.swift: invalid JSON in \(path): \(error)\n", stderr)
    exit(2)
  }
  guard let dict = obj as? [String: Any] else {
    fputs("print-issues.swift: expected a JSON object in \(path)\n", stderr)
    exit(2)
  }
  return dict
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

guard args.count == 2 else { usage() }

let status: Int32
switch args[0] {
case "--xcresult":
  status = fromXcresult(readJSONObject(from: args[1]))
case "--swift-log":
  status = fromSwiftLog(readText(from: args[1]))
default:
  usage()
}
exit(status)
