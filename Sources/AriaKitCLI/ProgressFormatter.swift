import AriaKit
import Foundation

/// Text for download rows: sizes, speeds, and progress bars.
enum ProgressFormatter {
  static func bytes(_ count: Int64) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var value = Double(count)
    var unit = 0
    while value >= 1024, unit < units.count - 1 {
      value /= 1024
      unit += 1
    }
    return unit == 0 ? "\(count) B" : String(format: "%.1f", value) + " " + units[unit]
  }

  static func bar(_ fraction: Double?, width: Int = 20) -> String {
    let filled = min(width, max(0, Int((fraction ?? 0) * Double(width))))
    return "[" + String(repeating: "#", count: filled) + String(repeating: "-", count: width - filled) + "]"
  }

  static func percent(_ fraction: Double?) -> String {
    guard let fraction else { return "  ?%" }
    let value = Int((fraction * 100).rounded(.down))
    return String(repeating: " ", count: max(0, 3 - String(value).count)) + "\(value)%"
  }

  static func row(position: Int, status: DownloadStatus) -> String {
    let name = status.files.first.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).lastPathComponent } ?? "…"
    let state = status.state == .error ? "error \(status.errorCode)" : "\(status.state)"
    let size = "\(bytes(status.completedLength)) / \(status.totalLength > 0 ? bytes(status.totalLength) : "?")"
    let speed = status.state == .active ? "\(bytes(Int64(status.downloadSpeed)))/s" : ""
    return "#\(position) \(bar(status.progress)) \(percent(status.progress))  \(size)  \(speed)  \(state)  \(name)"
  }
}
