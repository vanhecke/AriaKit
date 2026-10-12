import AriaKit
import Foundation
import Testing

/// libaria2 allows one session per process: every session test lives here, serialized.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AriaSessionTests {
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
}
