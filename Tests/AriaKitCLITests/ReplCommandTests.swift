import Foundation
import Testing
@testable import AriaKitCLI

@Suite
struct ReplCommandTests {
  @Test
  func bareURLsAreSeparateDownloads() throws {
    let first = try #require(URL(string: "https://example.com/a.iso"))
    let second = try #require(URL(string: "https://example.com/b.iso"))
    #expect(
      ReplCommand.parse("https://example.com/a.iso https://example.com/b.iso") == .add([.url(first), .url(second)])
    )
  }

  @Test
  func addKeywordMagnetAndSFTP() throws {
    let magnet = try #require(URL(string: "magnet:?xt=urn:btih:abc"))
    let sftp = try #require(URL(string: "sftp://host/file.bin"))
    #expect(ReplCommand.parse("add magnet:?xt=urn:btih:abc sftp://host/file.bin") == .add([.url(magnet), .url(sftp)]))
  }

  @Test
  func localTorrentAndMetalinkFiles() {
    #expect(ReplCommand.parse("/tmp/a.torrent") == .add([.torrent(URL(fileURLWithPath: "/tmp/a.torrent"))]))
    #expect(ReplCommand.parse("/tmp/b.META4") == .add([.metalink(URL(fileURLWithPath: "/tmp/b.META4"))]))
    #expect(ReplCommand.parse("file:///tmp/c.metalink") == .add([.metalink(URL(fileURLWithPath: "/tmp/c.metalink"))]))
    let home = NSString(string: "~").expandingTildeInPath
    #expect(ReplCommand.parse("~/a.torrent") == .add([.torrent(URL(fileURLWithPath: home + "/a.torrent"))]))
  }

  /// A path dragged into the terminal arrives with backslash-escaped spaces.
  @Test
  func escapedSpacesStayInOneWord() {
    let file = URL(fileURLWithPath: "/tmp/My Linux ISO.torrent")
    #expect(ReplCommand.parse(#"/tmp/My\ Linux\ ISO.torrent"#) == .add([.torrent(file)]))
  }

  /// Command-line arguments are whole words already: no escaping needed.
  @Test
  func argumentsAreWholeWords() {
    let file = URL(fileURLWithPath: "/tmp/My Linux ISO.torrent")
    #expect(ReplCommand.add(["/tmp/My Linux ISO.torrent"]) == .add([.torrent(file)]))
  }

  @Test
  func positionCommands() {
    #expect(ReplCommand.parse("pause 2") == .pause(2))
    #expect(ReplCommand.parse("resume 1") == .resume(1))
    #expect(ReplCommand.parse("rm 3") == .remove(3))
  }

  @Test
  func rejectsBadInput() {
    #expect(ReplCommand.parse("pause zero") == .invalid("usage: pause <n>"))
    #expect(ReplCommand.parse("pause 0") == .invalid("usage: pause <n>"))
    #expect(ReplCommand.parse("add") == .invalid("add needs at least one URL or file"))
    #expect(ReplCommand.parse("hello") == .invalid("not a URL, .torrent / .metalink file, or command: hello (try help)"))
    #expect(
      ReplCommand.parse("/tmp/notes.txt")
        == .invalid("not a URL, .torrent / .metalink file, or command: /tmp/notes.txt (try help)")
    )
  }

  @Test
  func keywords() {
    #expect(ReplCommand.parse("  ") == .empty)
    #expect(ReplCommand.parse("ls") == .list)
    #expect(ReplCommand.parse("QUIT") == .quit)
    #expect(ReplCommand.parse("help") == .help)
  }
}
