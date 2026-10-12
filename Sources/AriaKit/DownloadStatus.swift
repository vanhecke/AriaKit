/// Snapshot of one download's progress.
public struct DownloadStatus: Hashable, Sendable {

  // MARK: Lifecycle

  /// Creates a snapshot.
  public init(
    id: DownloadID,
    state: State,
    totalLength: Int64,
    completedLength: Int64,
    downloadSpeed: Int,
    uploadSpeed: Int,
    errorCode: Int,
    directory: String,
    files: [String],
    following: DownloadID? = nil,
    followedBy: [DownloadID] = [],
  ) {
    self.id = id
    self.state = state
    self.totalLength = totalLength
    self.completedLength = completedLength
    self.downloadSpeed = downloadSpeed
    self.uploadSpeed = uploadSpeed
    self.errorCode = errorCode
    self.directory = directory
    self.files = files
    self.following = following
    self.followedBy = followedBy
  }

  // MARK: Public

  /// Lifecycle state, mirroring `aria2::DownloadStatus`.
  public enum State: Hashable, Sendable {
    case active
    case waiting
    case paused
    case complete
    case error
    case removed

    // MARK: Lifecycle

    /// Maps `aria2::DownloadStatus` (0-based) to a state.
    init?(rawValue: Int32) {
      let states: [Self] = [.active, .waiting, .paused, .complete, .error, .removed]
      guard states.indices.contains(Int(rawValue)) else { return nil }
      self = states[Int(rawValue)]
    }

    // MARK: Public

    /// Whether aria2 will do no more work on the download.
    public var isFinished: Bool {
      switch self {
      case .complete,
           .error,
           .removed: true
      case .active,
           .waiting,
           .paused: false
      }
    }
  }

  /// The download.
  public let id: DownloadID
  /// Lifecycle state.
  public let state: State
  /// Total size in bytes, 0 while unknown.
  public let totalLength: Int64
  /// Bytes downloaded so far.
  public let completedLength: Int64
  /// Download speed in bytes per second.
  public let downloadSpeed: Int
  /// Upload speed in bytes per second (BitTorrent).
  public let uploadSpeed: Int
  /// aria2 exit-status code of the last error, 0 if none.
  public let errorCode: Int
  /// Directory files are saved to.
  public let directory: String
  /// Paths of the files this download writes. Empty until aria2 knows them.
  public let files: [String]
  /// The download this one continues, e.g. the `.torrent` or magnet that produced it.
  public let following: DownloadID?
  /// Downloads aria2 started from this one's result: the content of a `.torrent` URL or
  /// magnet link, or the files of a Metalink. Empty until this download completes.
  public let followedBy: [DownloadID]

  /// Fraction downloaded in `0...1`, or `nil` while the size is unknown.
  public var progress: Double? {
    guard totalLength > 0 else { return nil }
    return Double(completedLength) / Double(totalLength)
  }

  /// What ``errorCode`` means, per aria2's exit-status table; `nil` when there is no error.
  ///
  /// libaria2 exposes only the code. Details such as the HTTP status are in aria2's
  /// log (the `log` option).
  public var errorDescription: String? {
    guard errorCode != 0 else { return nil }
    guard Self.errorDescriptions.indices.contains(errorCode) else { return "unrecognized aria2 error" }
    return Self.errorDescriptions[errorCode]
  }

  // MARK: Private

  /// Indexed by aria2 `error_code::Value` (src/error_code.h); index 0 is success.
  private static let errorDescriptions = [
    "finished",
    "unknown error",
    "timed out",
    "resource not found",
    "resource not found too many times (max-file-not-found)",
    "aborted: download too slow (lowest-speed-limit)",
    "network problem",
    "unfinished when the session stopped",
    "server cannot resume, but resume was required",
    "not enough disk space",
    "piece length differs from the .aria2 control file",
    "this file is already being downloaded",
    "this torrent is already being downloaded",
    "file already exists",
    "could not rename file",
    "could not open existing file",
    "could not create or truncate file",
    "file I/O error",
    "could not create directory",
    "could not resolve host name",
    "could not parse Metalink document",
    "FTP command failed",
    "server returned an HTTP error or unexpected response (e.g. 403, 5xx)",
    "too many redirects",
    "HTTP authorization failed",
    "could not parse bencoded file",
    "torrent file is corrupt or incomplete",
    "bad magnet URI",
    "bad or unrecognized option",
    "server temporarily overloaded or in maintenance",
    "could not parse JSON-RPC request",
    "removed",
    "checksum validation failed",
  ]

}
