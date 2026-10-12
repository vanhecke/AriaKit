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

  /// Fraction downloaded in `0...1`, or `nil` while the size is unknown.
  public var progress: Double? {
    guard totalLength > 0 else { return nil }
    return Double(completedLength) / Double(totalLength)
  }

}
