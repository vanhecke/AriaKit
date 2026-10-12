import Testing
@testable import AriaKitCLI

@Suite
struct CommandTests {
  @Test
  func connectionsDefaultToFour() throws {
    #expect(try AriaKitCommand.parse([]).connections == 4)
  }

  @Test
  func connectionsWithinAria2Limits() throws {
    #expect(try AriaKitCommand.parse(["--connections", "16"]).connections == 16)
    #expect(try AriaKitCommand.parse(["-c", "1"]).connections == 1)
    #expect(throws: (any Error).self) { try AriaKitCommand.parse(["--connections", "0"]) }
    #expect(throws: (any Error).self) { try AriaKitCommand.parse(["--connections", "17"]) }
  }
}
