import Testing
@testable import AriaKit

@Suite
struct DownloadStatusTests {

  // MARK: Internal

  @Test
  func progressIsNilWhileSizeUnknown() {
    #expect(status(total: 0, completed: 0).progress == nil)
  }

  @Test
  func progressIsFraction() {
    #expect(status(total: 200, completed: 50).progress == 0.25)
  }

  @Test
  func mapsAria2States() {
    #expect(DownloadStatus.State(rawValue: 0) == .active)
    #expect(DownloadStatus.State(rawValue: 5) == .removed)
    #expect(DownloadStatus.State(rawValue: 6) == nil)
  }

  @Test
  func mapsAria2Events() {
    let id = DownloadID(rawValue: 7)
    #expect(DownloadEvent(rawEvent: 1, id: id)?.kind == .started)
    #expect(DownloadEvent(rawEvent: 5, id: id)?.kind == .failed)
    #expect(DownloadEvent(rawEvent: 0, id: id) == nil)
  }

  @Test
  func errorDescriptionExplainsAria2Codes() {
    #expect(status().errorDescription == nil)
    #expect(status(errorCode: 22).errorDescription == "server returned an HTTP error or unexpected response (e.g. 403, 5xx)")
    #expect(status(errorCode: 32).errorDescription == "checksum validation failed")
    #expect(status(errorCode: 99).errorDescription == "unrecognized aria2 error")
  }

  // MARK: Private

  private func status(total: Int64 = 0, completed: Int64 = 0, errorCode: Int = 0) -> DownloadStatus {
    DownloadStatus(
      id: DownloadID(rawValue: 1),
      state: .active,
      totalLength: total,
      completedLength: completed,
      downloadSpeed: 0,
      uploadSpeed: 0,
      errorCode: errorCode,
      directory: "/tmp",
      files: [],
    )
  }

}
