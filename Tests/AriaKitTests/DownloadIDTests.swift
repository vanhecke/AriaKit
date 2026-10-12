import AriaKit
import Testing

@Suite
struct DownloadIDTests {
  @Test
  func descriptionIsSixteenHexDigits() {
    #expect(DownloadID(rawValue: 0x2A).description == "000000000000002a")
  }

  @Test
  func hexRoundTrips() {
    let id = DownloadID(rawValue: 0xDEAD_BEEF_0123_4567)
    #expect(DownloadID(hex: id.description) == id)
  }

  @Test
  func rejectsShortHex() {
    #expect(DownloadID(hex: "2a") == nil)
  }
}
