import AriaKit
import Testing
@testable import AriaKitCLI

@Suite
struct ProgressFormatterTests {
  @Test
  func bytes() {
    #expect(ProgressFormatter.bytes(512) == "512 B")
    #expect(ProgressFormatter.bytes(1536) == "1.5 KiB")
    #expect(ProgressFormatter.bytes(3 * 1024 * 1024 * 1024) == "3.0 GiB")
  }

  @Test
  func bar() {
    #expect(ProgressFormatter.bar(0.5, width: 4) == "[##--]")
    #expect(ProgressFormatter.bar(nil, width: 2) == "[--]")
    #expect(ProgressFormatter.bar(2, width: 2) == "[##]")
  }

  @Test
  func percent() {
    #expect(ProgressFormatter.percent(0.425) == " 42%")
    #expect(ProgressFormatter.percent(nil) == "  ?%")
  }

  @Test
  func row() {
    let status = DownloadStatus(
      id: DownloadID(rawValue: 1),
      state: .active,
      totalLength: 2048,
      completedLength: 1024,
      downloadSpeed: 1024,
      uploadSpeed: 0,
      errorCode: 0,
      directory: "/tmp",
      files: ["/tmp/file.iso"],
    )
    #expect(
      ProgressFormatter.row(position: 1, status: status)
        == "#1 [##########----------]  50%  1.0 KiB / 2.0 KiB  1.0 KiB/s  active  file.iso"
    )
  }
}
