import AriaKit
import Foundation

/// Reads commands from stdin and dispatches them to the session.
///
/// Interactive (TTY): live download list redrawn twice a second, input line at
/// the bottom. Piped: one command per line; events to stdout, errors to stderr;
/// exits once stdin ends and every download has finished.
@MainActor
final class Console {

  // MARK: Lifecycle

  init(session: AriaSession, interactive: Bool) {
    self.session = session
    self.interactive = interactive
  }

  // MARK: Internal

  /// Runs until quit or end of input, then shuts the session down.
  /// Returns `false` if any download failed.
  func run(initialInput: [String]) async -> Bool {
    let terminal = interactive ? Terminal.enterRawMode() : nil
    let eventTask = Task {
      for await event in session.events {
        await handle(event)
      }
    }
    let renderTask = Task {
      while !Task.isCancelled, interactive {
        await refresh()
        render()
        try? await Task.sleep(for: .milliseconds(500))
      }
    }

    for input in initialInput {
      await execute(ReplCommand.parse(input))
    }
    render()
    for await chunk in InputReader.chunks() {
      for byte in chunk where !quitRequested {
        await receive(byte)
      }
      if quitRequested {
        break
      }
    }
    if !interactive, !quitRequested {
      await execute(ReplCommand.parse(String(decoding: line, as: UTF8.self)))
      await waitUntilFinished()
    }

    renderTask.cancel()
    await refresh()
    await session.shutdown()
    await eventTask.value
    terminal?.restore()
    if interactive {
      listDownloads()
    }
    return !downloads.contains { statuses[$0]?.state == .error }
  }

  // MARK: Private

  private enum EscapeState {
    case none
    case escape
    case sequence
  }

  private let session: AriaSession
  private let interactive: Bool
  private var downloads = [DownloadID]()
  private var statuses = [DownloadID: DownloadStatus]()
  private var sources = [DownloadID: URL]()
  private var messages = [String]()
  private var line = [UInt8]()
  private var escapeState = EscapeState.none
  private var quitRequested = false

  private func receive(_ byte: UInt8) async {
    guard interactive else {
      if byte == UInt8(ascii: "\n") {
        await submitLine()
      } else {
        line.append(byte)
      }
      return
    }
    switch (escapeState, byte) {
    case (.escape, UInt8(ascii: "[")),
         (.escape, UInt8(ascii: "O")):
      escapeState = .sequence
    case (.escape, _):
      escapeState = .none
    case (.sequence, 0x40 ... 0x7E):
      escapeState = .none
    case (.sequence, _):
      break
    case (.none, 0x1B):
      escapeState = .escape
    case (.none, 0x03):
      quitRequested = true
    case (.none, 0x04) where line.isEmpty:
      quitRequested = true
    case (.none, 0x0D),
         (.none, 0x0A):
      await submitLine()
    case (.none, 0x7F),
         (.none, 0x08):
      deleteLastCharacter()
    case (.none, 0x20...):
      line.append(byte)
    default:
      break
    }
    render()
  }

  private func submitLine() async {
    let text = String(decoding: line, as: UTF8.self)
    line.removeAll()
    await execute(ReplCommand.parse(text))
  }

  private func deleteLastCharacter() {
    // Drop UTF-8 continuation bytes (10xxxxxx), then the lead byte.
    while let last = line.last, last & 0xC0 == 0x80 {
      line.removeLast()
    }
    if !line.isEmpty {
      line.removeLast()
    }
  }

  private func execute(_ command: ReplCommand) async {
    do {
      switch command {
      case .add(let urls):
        for url in urls {
          let id = try await session.add([url])
          downloads.append(id)
          sources[id] = url
          note("#\(downloads.count) added \(url.absoluteString)")
        }

      case .pause(let position):
        try await session.pause(download(at: position))

      case .resume(let position):
        try await session.resume(download(at: position))

      case .remove(let position):
        try await session.remove(download(at: position))

      case .list:
        await refresh()
        listDownloads()

      case .help:
        for item in ReplCommand.usage.split(separator: "\n") { note(String(item)) }

      case .quit:
        quitRequested = true

      case .empty:
        break

      case .invalid(let message):
        fail(message)
      }
    } catch {
      fail("\(error)")
    }
    await refresh()
  }

  private func download(at position: Int) throws -> DownloadID {
    guard downloads.indices.contains(position - 1) else { throw ConsoleError.noSuchDownload(position) }
    return downloads[position - 1]
  }

  private func handle(_ event: DownloadEvent) async {
    if let status = try? await session.status(of: event.id) {
      statuses[event.id] = status
    }
    guard event.kind != .started else { return }
    let label = downloads.firstIndex(of: event.id).map { "#\($0 + 1)" } ?? "\(event.id)"
    let name = ProgressFormatter.name(status: statuses[event.id], source: sources[event.id])
    switch event.kind {
    case .failed:
      let status = statuses[event.id]
      let reason = status?.errorDescription ?? "unknown error"
      fail("\(label) \(name) failed: \(reason) (aria2 error \(status?.errorCode ?? -1))")

    default: note("\(label) \(event.kind) \(name)")
    }
    render()
  }

  private func refresh() async {
    for id in downloads {
      if let status = try? await session.status(of: id) {
        statuses[id] = status
      }
    }
  }

  private func waitUntilFinished() async {
    while downloads.contains(where: { statuses[$0].map { !$0.state.isFinished } ?? false }) {
      try? await Task.sleep(for: .milliseconds(500))
      await refresh()
    }
  }

  private func listDownloads() {
    for (index, id) in downloads.enumerated() {
      let row = statuses[id].map { ProgressFormatter.row(
        position: index + 1,
        status: $0,
        source: sources[id],
      ) } ?? "#\(index + 1) \(id)"
      Terminal.write(row + "\n")
    }
  }

  private func note(_ message: String) {
    if interactive {
      messages.append(message)
    } else {
      Terminal.write(message + "\n")
    }
  }

  private func fail(_ message: String) {
    if interactive {
      messages.append("error: \(message)")
    } else {
      FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    }
  }

  private func render() {
    guard interactive else { return }
    var rows = ["ariakit — \(downloads.count) download(s). Type a URL, or help.", ""]
    for (index, id) in downloads.enumerated() {
      rows
        .append(statuses[id]
          .map { ProgressFormatter.row(position: index + 1, status: $0, source: sources[id]) } ?? "#\(index + 1) \(id)")
    }
    rows.append("")
    rows += messages.suffix(8)
    var screen = "\u{1B}[H"
    for row in rows {
      screen += row + "\u{1B}[K\n"
    }
    screen += "> " + String(decoding: line, as: UTF8.self) + "\u{1B}[K\u{1B}[J"
    Terminal.write(screen)
  }

}

/// Errors from commands that reference the download list.
enum ConsoleError: Error, CustomStringConvertible {
  case noSuchDownload(Int)

  var description: String {
    switch self {
    case .noSuchDownload(let position): "no download #\(position)"
    }
  }
}
