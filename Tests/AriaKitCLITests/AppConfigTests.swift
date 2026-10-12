import Testing

@testable import AriaKitCLI

@Suite
struct AppConfigTests {
  @Test
  func defaultVersionIsZero() {
    #expect(AppConfig().version == "0.0.0")
  }
}
