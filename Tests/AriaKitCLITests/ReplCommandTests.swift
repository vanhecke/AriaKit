import Foundation
import Testing
@testable import AriaKitCLI

@Suite
struct ReplCommandTests {
  @Test
  func bareURLsAreSeparateDownloads() throws {
    let first = try #require(URL(string: "https://example.com/a.iso"))
    let second = try #require(URL(string: "https://example.com/b.iso"))
    #expect(ReplCommand.parse("https://example.com/a.iso https://example.com/b.iso") == .add([first, second]))
  }

  @Test
  func addKeywordAndMagnet() throws {
    let magnet = try #require(URL(string: "magnet:?xt=urn:btih:abc"))
    #expect(ReplCommand.parse("add magnet:?xt=urn:btih:abc") == .add([magnet]))
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
    #expect(ReplCommand.parse("add") == .invalid("add needs at least one URL"))
    #expect(ReplCommand.parse("hello") == .invalid("not a URL or command: hello (try help)"))
  }

  @Test
  func keywords() {
    #expect(ReplCommand.parse("  ") == .empty)
    #expect(ReplCommand.parse("ls") == .list)
    #expect(ReplCommand.parse("QUIT") == .quit)
    #expect(ReplCommand.parse("help") == .help)
  }
}
