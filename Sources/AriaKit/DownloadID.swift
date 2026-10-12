/// Identifier aria2 assigns to a download (its GID).
public struct DownloadID: Hashable, Sendable, CustomStringConvertible {
  /// Wraps a raw GID.
  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  /// Parses the 16-digit hex form aria2 prints.
  public init?(hex: String) {
    guard hex.count == 16, let value = UInt64(hex, radix: 16) else { return nil }
    rawValue = value
  }

  /// Raw 64-bit GID.
  public let rawValue: UInt64

  /// The 16-digit lowercase hex form aria2 prints.
  public var description: String {
    let hex = String(rawValue, radix: 16)
    return String(repeating: "0", count: 16 - hex.count) + hex
  }
}
