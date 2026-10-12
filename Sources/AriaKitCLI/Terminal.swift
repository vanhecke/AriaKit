import Foundation

/// The controlling TTY in non-canonical, no-echo mode on the alternate screen.
/// ``restore()`` puts it back.
struct Terminal {

  // MARK: Internal

  /// Switches stdin to key-at-a-time input. `nil` if stdin is not a TTY.
  static func enterRawMode() -> Self? {
    var original = termios()
    guard tcgetattr(STDIN_FILENO, &original) == 0 else { return nil }
    var raw = original
    raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
    guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return nil }
    write("\u{1B}[?1049h\u{1B}[H")
    return Self(original: original)
  }

  static func write(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
  }

  func restore() {
    var original = original
    tcsetattr(STDIN_FILENO, TCSANOW, &original)
    Self.write("\u{1B}[?1049l")
  }

  // MARK: Private

  private let original: termios

}
