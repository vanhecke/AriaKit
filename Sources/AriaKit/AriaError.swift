/// Errors thrown by ``AriaSession``.
public enum AriaError: Error, Hashable, Sendable {
  /// libaria2 allows one session per process and another is running.
  case sessionAlreadyActive
  /// `aria2::sessionNew` rejected the options.
  case sessionCreationFailed
  /// The session has shut down.
  case sessionClosed
  /// aria2 does not know this download (never added, or purged).
  case unknownDownload(DownloadID)
  /// A libaria2 call returned a non-zero code.
  case operationFailed(code: Int)
}
