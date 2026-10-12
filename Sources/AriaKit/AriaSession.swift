internal import AriaShim
import Foundation
import Synchronization

/// A libaria2 download session running on its own thread.
///
/// libaria2 allows one session per process and is not thread-safe, so every
/// call is queued onto the session thread and runs between event-loop
/// iterations. An idle iteration can block for up to about one second, so a
/// command may take that long to start. Call ``shutdown()`` when done.
///
/// The first session sets `SIGPIPE` to ignored for the whole process, unless the
/// process already installed its own handler. Otherwise a server or peer closing a
/// connection mid-write would kill the process; writes to closed pipes and sockets
/// instead fail with `EPIPE`.
public final class AriaSession: Sendable {

  // MARK: Lifecycle

  /// Starts a session.
  ///
  /// - Parameter options: aria2 global options without the leading `--`,
  ///   such as `["dir": "/tmp", "max-concurrent-downloads": "3"]`.
  /// - Throws: ``AriaError/sessionAlreadyActive`` or ``AriaError/sessionCreationFailed``.
  public init(options: [String: String] = [:]) async throws {
    guard Self.isActive.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing).exchanged
    else { throw AriaError.sessionAlreadyActive }
    let (events, continuation) = AsyncStream.makeStream(of: DownloadEvent.self)
    self.events = events
    let mailbox = mailbox
    try await withCheckedThrowingContinuation { (started: CheckedContinuation<Void, any Error>) in
      let thread = Thread {
        Self.runLoop(options: options, mailbox: mailbox, events: continuation, started: started)
      }
      thread.name = "AriaKit.session"
      thread.start()
    }
  }

  // MARK: Public

  /// Download events, in the order libaria2 reports them. Finishes after ``shutdown()``.
  public let events: AsyncStream<DownloadEvent>

  /// Queues a download of one file from one or more mirrors of it.
  ///
  /// - Parameters:
  ///   - urls: Mirrors of the same file: HTTP(S), FTP, or SFTP URLs, or one magnet link.
  ///     A magnet link or a URL to a `.torrent` / Metalink file completes once that
  ///     metadata is fetched; the content continues as new downloads listed in
  ///     ``DownloadStatus/followedBy``.
  ///   - options: Per-download aria2 options, such as `["out": "name.iso"]`.
  public func add(_ urls: [URL], options: [String: String] = [:]) async throws -> DownloadID {
    try await perform { session in
      var uris = ariashim.StringList()
      for url in urls {
        ariashim.appendString(&uris, url.absoluteString)
      }
      let result = ariashim.addUri(session, uris, Self.keyVals(options))
      try Self.check(result.code)
      return DownloadID(rawValue: result.gid)
    }
  }

  /// Queues the download a local `.torrent` file describes.
  ///
  /// A `.torrent` reachable by URL can go to ``add(_:options:)`` instead: aria2
  /// fetches it and continues with the content as a new download (see
  /// ``DownloadStatus/followedBy``).
  ///
  /// - Parameters:
  ///   - torrentFile: Path of the `.torrent` file.
  ///   - options: Per-download aria2 options, such as `["seed-time": "0"]`.
  public func addTorrent(_ torrentFile: URL, options: [String: String] = [:]) async throws -> DownloadID {
    try await perform { session in
      let result = ariashim.addTorrent(session, torrentFile.path, Self.keyVals(options))
      try Self.check(result.code)
      return DownloadID(rawValue: result.gid)
    }
  }

  /// Queues every file a local Metalink (`.metalink` / `.meta4`) document describes.
  ///
  /// - Parameters:
  ///   - metalinkFile: Path of the Metalink document.
  ///   - options: Per-download aria2 options, applied to each file.
  /// - Returns: One download per file, in document order.
  public func addMetalink(_ metalinkFile: URL, options: [String: String] = [:]) async throws -> [DownloadID] {
    try await perform { session in
      let result = ariashim.addMetalink(session, metalinkFile.path, Self.keyVals(options))
      try Self.check(result.code)
      return (0 ..< ariashim.addedCount(result)).map { DownloadID(rawValue: ariashim.addedGid(result, $0)) }
    }
  }

  /// Pauses a download. It keeps its place and resumes with ``resume(_:)``.
  public func pause(_ id: DownloadID) async throws {
    try await perform { session in try Self.check(ariashim.pauseDownload(session, id.rawValue, false)) }
  }

  /// Resumes a paused download.
  public func resume(_ id: DownloadID) async throws {
    try await perform { session in try Self.check(ariashim.unpauseDownload(session, id.rawValue)) }
  }

  /// Stops and removes a download. Its status remains readable as ``DownloadStatus/State/removed``.
  public func remove(_ id: DownloadID) async throws {
    try await perform { session in try Self.check(ariashim.removeDownload(session, id.rawValue, false)) }
  }

  /// Returns a progress snapshot of a download.
  public func status(of id: DownloadID) async throws -> DownloadStatus {
    try await perform { session in
      let snapshot = ariashim.snapshot(session, id.rawValue)
      guard snapshot.found, let state = DownloadStatus.State(rawValue: snapshot.status) else {
        throw AriaError.unknownDownload(id)
      }
      return DownloadStatus(
        id: id,
        state: state,
        totalLength: snapshot.totalLength,
        completedLength: snapshot.completedLength,
        downloadSpeed: Int(snapshot.downloadSpeed),
        uploadSpeed: Int(snapshot.uploadSpeed),
        errorCode: Int(snapshot.errorCode),
        directory: String(cString: ariashim.snapshotDirectory(snapshot)),
        files: (0 ..< ariashim.snapshotFileCount(snapshot)).map { String(cString: ariashim.snapshotFile(snapshot, $0)) },
        following: snapshot.following == 0 ? nil : DownloadID(rawValue: snapshot.following),
        followedBy: (0 ..< ariashim.snapshotFollowedByCount(snapshot)).map {
          DownloadID(rawValue: ariashim.snapshotFollowedBy(snapshot, $0))
        },
      )
    }
  }

  /// Stops all downloads, saves their control files, and ends the session.
  /// Returns once the session thread has exited.
  public func shutdown() async {
    await withCheckedContinuation { continuation in
      mailbox.requestShutdown(onFinish: continuation)
    }
  }

  // MARK: Private

  private static let isActive = Atomic(false)

  private let mailbox = Mailbox()

  private static func check(_ code: Int32) throws {
    guard code == 0 else { throw AriaError.operationFailed(code: Int(code)) }
  }

  private static func keyVals(_ options: [String: String]) -> ariashim.KeyVals {
    var keyVals = ariashim.KeyVals()
    for (key, value) in options.sorted(by: { $0.key < $1.key }) {
      ariashim.appendOption(&keyVals, key, value)
    }
    return keyVals
  }

  /// Body of the session thread: owns the `aria2::Session` from creation to final.
  private static func runLoop(
    options: [String: String],
    mailbox: Mailbox,
    events: AsyncStream<DownloadEvent>.Continuation,
    started: CheckedContinuation<Void, any Error>,
  ) {
    guard ariashim.libraryInit() == 0 else {
      events.finish()
      isActive.store(false, ordering: .releasing)
      started.resume(throwing: AriaError.sessionCreationFailed)
      return
    }
    let sink = Unmanaged.passRetained(EventSink(continuation: events))
    let callback: ariashim.EventCallback = { rawEvent, gid, context in
      guard let context, let event = DownloadEvent(rawEvent: rawEvent, id: DownloadID(rawValue: gid)) else { return }
      Unmanaged<EventSink>.fromOpaque(context).takeUnretainedValue().continuation.yield(event)
    }
    guard let session = ariashim.sessionNew(keyVals(options), callback, sink.toOpaque()) else {
      sink.release()
      events.finish()
      isActive.store(false, ordering: .releasing)
      started.resume(throwing: AriaError.sessionCreationFailed)
      return
    }
    started.resume()

    var shutdownScheduled = false
    while true {
      for command in mailbox.takeCommands() {
        command.run(session)
      }
      if !shutdownScheduled, mailbox.isShutdownRequested {
        _ = ariashim.shutdown(session, false)
        shutdownScheduled = true
      }
      if ariashim.runOnce(session) != 1 {
        break
      }
    }

    _ = ariashim.sessionFinal(session)
    sink.release()
    events.finish()
    isActive.store(false, ordering: .releasing)
    mailbox.close()
  }

  private func perform<T: Sendable>(_ body: @escaping @Sendable (OpaquePointer) throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      mailbox.enqueue(
        Mailbox.Command(
          run: { session in continuation.resume(with: Result { try body(session) }) },
          cancel: { continuation.resume(throwing: AriaError.sessionClosed) },
        )
      )
    }
  }

}

/// Holds the event continuation for the C callback's `userData`.
private final class EventSink: Sendable {

  // MARK: Lifecycle

  init(continuation: AsyncStream<DownloadEvent>.Continuation) {
    self.continuation = continuation
  }

  // MARK: Internal

  let continuation: AsyncStream<DownloadEvent>.Continuation

}

/// Commands queued for the session thread, plus shutdown bookkeeping.
private final class Mailbox: Sendable {

  // MARK: Internal

  struct Command {
    let run: @Sendable (OpaquePointer) -> Void
    let cancel: @Sendable () -> Void
  }

  var isShutdownRequested: Bool {
    state.withLock { $0.isShutdownRequested }
  }

  func enqueue(_ command: Command) {
    let accepted = state.withLock { state in
      guard !state.isClosed, !state.isShutdownRequested else { return false }
      state.commands.append(command)
      return true
    }
    if !accepted {
      command.cancel()
    }
  }

  func takeCommands() -> [Command] {
    state.withLock { state in
      defer { state.commands.removeAll() }
      return state.commands
    }
  }

  func requestShutdown(onFinish waiter: CheckedContinuation<Void, Never>) {
    let isClosed = state.withLock { state in
      state.isShutdownRequested = true
      if !state.isClosed {
        state.shutdownWaiters.append(waiter)
      }
      return state.isClosed
    }
    if isClosed {
      waiter.resume()
    }
  }

  /// Marks the session gone: cancels queued commands and wakes ``requestShutdown(onFinish:)`` callers.
  func close() {
    let (commands, waiters) = state.withLock { state in
      state.isClosed = true
      defer {
        state.commands.removeAll()
        state.shutdownWaiters.removeAll()
      }
      return (state.commands, state.shutdownWaiters)
    }
    for command in commands {
      command.cancel()
    }
    for waiter in waiters {
      waiter.resume()
    }
  }

  // MARK: Private

  private struct State {
    var commands = [Command]()
    var isShutdownRequested = false
    var isClosed = false
    var shutdownWaiters = [CheckedContinuation<Void, Never>]()
  }

  private let state = Mutex(State())

}
