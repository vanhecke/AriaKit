/// A state change libaria2 reports for one download.
public struct DownloadEvent: Hashable, Sendable {

  // MARK: Lifecycle

  /// Creates an event.
  public init(kind: Kind, id: DownloadID) {
    self.kind = kind
    self.id = id
  }

  /// Maps `aria2::DownloadEvent` (1-based) to an event.
  init?(rawEvent: Int32, id: DownloadID) {
    let kinds: [Kind] = [.started, .paused, .stopped, .completed, .failed, .bitTorrentCompleted]
    guard (1 ... Int32(kinds.count)).contains(rawEvent) else { return nil }
    self.init(kind: kinds[Int(rawEvent) - 1], id: id)
  }

  // MARK: Public

  /// What happened.
  public enum Kind: Hashable, Sendable {
    case started
    case paused
    case stopped
    case completed
    case failed
    case bitTorrentCompleted
  }

  /// What happened.
  public let kind: Kind
  /// The download it happened to.
  public let id: DownloadID

}
