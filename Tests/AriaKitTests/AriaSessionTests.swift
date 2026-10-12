import AriaKit
import Foundation
import Testing
#if canImport(Glibc)
import Glibc
#endif

/// libaria2 allows one session per process: every session test lives here, serialized.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AriaSessionTests {

  // MARK: Internal

  @Test
  func failedDownloadReportsEventAndStatus() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let session = try await AriaSession(options: ["dir": directory.path, "max-tries": "1"])
    // Port 1 on loopback refuses the connection: no live network.
    let id = try await session.add([#require(URL(string: "http://127.0.0.1:1/missing"))])

    let event = await session.events.first { $0.id == id && $0.kind != .started }
    #expect(event?.kind == .failed)
    let status = try await session.status(of: id)
    #expect(status.state == .error)
    #expect(status.errorCode != 0)

    await session.shutdown()
    await #expect(throws: AriaError.sessionClosed) {
      try await session.status(of: id)
    }
  }

  @Test
  func secondSessionIsRejected() async throws {
    let session = try await AriaSession()
    await #expect(throws: AriaError.sessionAlreadyActive) {
      _ = try await AriaSession()
    }
    await session.shutdown()
  }

  /// A server or peer closing a connection mid-write raised SIGPIPE and killed the host
  /// process. With a session started, such a write must fail with EPIPE instead.
  @Test
  func writeToClosedPipeFailsInsteadOfKillingProcess() async throws {
    let session = try await AriaSession()
    var fds: [Int32] = [0, 0]
    #expect(pipe(&fds) == 0)
    close(fds[0])
    let written = write(fds[1], "x", 1)
    let error = errno
    close(fds[1])
    #expect(written == -1)
    #expect(error == EPIPE)
    await session.shutdown()
  }

  @Test
  func localTorrentDescribesItsContent() async throws {
    let directory = try Self.temporaryDirectory()
    let torrent = directory.appending(path: "a.torrent")
    try Self.torrent.write(to: torrent)
    let session = try await AriaSession(options: Self.offlineOptions(directory))

    let id = try await session.addTorrent(torrent)
    let status = try await session.status(of: id)
    #expect(status.totalLength == 1)
    #expect(status.files.map { URL(fileURLWithPath: $0).lastPathComponent } == ["a.txt"])

    await session.shutdown()
  }

  @Test
  func localMetalinkAddsOneDownloadPerFile() async throws {
    let directory = try Self.temporaryDirectory()
    let metalink = directory.appending(path: "files.meta4")
    try Data(
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <metalink xmlns="urn:ietf:params:xml:ns:metalink">
        <file name="one.bin"><url>http://127.0.0.1:1/one.bin</url></file>
        <file name="two.bin"><url>http://127.0.0.1:1/two.bin</url></file>
      </metalink>
      """.utf8
    ).write(to: metalink)
    let session = try await AriaSession(options: Self.offlineOptions(directory))

    let ids = try await session.addMetalink(metalink)
    #expect(ids.count == 2)
    var names = [String]()
    for id in ids {
      try await names += session.status(of: id).files.map { URL(fileURLWithPath: $0).lastPathComponent }
    }
    #expect(names == ["one.bin", "two.bin"])

    await session.shutdown()
  }

  @Test
  func torrentURLContinuesAsFollowUpDownload() async throws {
    let directory = try Self.temporaryDirectory()
    let server = try LoopbackHTTPServer(body: Self.torrent, contentType: "application/x-bittorrent")
    defer { server.stop() }
    let session = try await AriaSession(options: Self.offlineOptions(directory))

    let id = try await session.add([#require(URL(string: "http://127.0.0.1:\(server.port)/a.torrent"))])
    let event = await session.events.first { $0.id == id && $0.kind != .started }
    #expect(event?.kind == .completed)

    let followedBy = try await session.status(of: id).followedBy
    #expect(followedBy.count == 1)
    let content = try await session.status(of: #require(followedBy.first))
    #expect(content.following == id)
    #expect(content.files.map { URL(fileURLWithPath: $0).lastPathComponent } == ["a.txt"])

    await session.shutdown()
  }

  // MARK: Private

  /// SHA-1 of the one-byte content "a": the only piece of ``torrent``.
  private static let pieceHash: [UInt8] = [
    0x86,
    0xF7,
    0xE4,
    0x37,
    0xFA,
    0xA5,
    0xA7,
    0xFC,
    0xE1,
    0x5D,
    0x1D,
    0xDC,
    0xB9,
    0xEA,
    0xEA,
    0xEA,
    0x37,
    0x76,
    0x67,
    0xB8,
  ]

  /// A trackerless single-file torrent of `a.txt` (1 byte).
  private static let torrent = Data("d4:infod6:lengthi1e4:name5:a.txt12:piece lengthi16384e6:pieces20:".utf8)
    + Data(pieceHash)
    + Data("ee".utf8)

  /// No DHT, peer exchange, or local peer discovery: BitTorrent stays off the network.
  private static func offlineOptions(_ directory: URL) -> [String: String] {
    [
      "dir": directory.path,
      "max-tries": "1",
      "enable-dht": "false",
      "enable-dht6": "false",
      "enable-peer-exchange": "false",
      "bt-enable-lpd": "false",
      "seed-time": "0",
    ]
  }

  private static func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

}
