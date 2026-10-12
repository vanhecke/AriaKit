import Testing

@testable import AriaKitCLI

@Suite
struct AppConfigTests {
  @Test
  func defaultVersionIsSemanticVersion() {
    #expect(AppConfig().version.wholeMatch(of: /\d+\.\d+\.\d+/) != nil)
  }
}
