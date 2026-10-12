import AriaKit
import Foundation
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
      ProgressFormatter.row(position: 1, status: status, source: nil)
        == "#1 [##########----------]  50%  1.0 KiB / 2.0 KiB  1.0 KiB/s  active  file.iso"
    )
  }

  /// Before aria2 names the file, the path is empty: never show the working directory's name.
  @Test
  func nameFallsBackToSourceURL() throws {
    let unnamed = DownloadStatus(
      id: DownloadID(rawValue: 1),
      state: .error,
      totalLength: 0,
      completedLength: 0,
      downloadSpeed: 0,
      uploadSpeed: 0,
      errorCode: 22,
      directory: "/tmp",
      files: [""],
    )
    let file = try #require(URL(string: "https://speed.cloudflare.com/__down?bytes=104857600"))
    let root = try #require(URL(string: "https://example.com/"))
    #expect(ProgressFormatter.name(status: unnamed, source: file) == "__down")
    #expect(ProgressFormatter.name(status: unnamed, source: root) == "example.com")
    #expect(ProgressFormatter.name(status: unnamed, source: nil) == "…")
  }
}
