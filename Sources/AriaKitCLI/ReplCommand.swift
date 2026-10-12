import Foundation

/// One line of input to the downloader.
enum ReplCommand: Equatable {
  /// Each URL becomes its own download.
  case add([URL])
  /// 1-based position in the download list.
  case pause(Int)
  case resume(Int)
  case remove(Int)
  case list
  case help
  case quit
  case empty
  case invalid(String)

  // MARK: Internal

  static let usage = """
    Commands (type while downloads run):
      <url> [<url>…]   add downloads (also: add <url>…)
      pause <n>        pause download #n
      resume <n>       resume download #n
      rm <n>           remove download #n
      ls               list downloads
      help             show this help
      quit             stop and exit (also Ctrl-D, Ctrl-C)
    """

  static func parse(_ line: String) -> Self {
    let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
    guard let first = words.first else { return .empty }
    let rest = Array(words.dropFirst())
    switch first.lowercased() {
    case "add": return rest.isEmpty ? .invalid("add needs at least one URL") : urls(rest)
    case "pause": return position(rest, usage: "pause <n>", make: Self.pause)
    case "resume": return position(rest, usage: "resume <n>", make: Self.resume)
    case "rm",
         "remove": return position(rest, usage: "rm <n>", make: Self.remove)
    case "ls",
         "list": return .list
    case "help",
         "?": return .help
    case "quit",
         "exit",
         "q": return .quit
    default: return urls(words)
    }
  }

  // MARK: Private

  private static func urls(_ words: [String]) -> Self {
    var urls = [URL]()
    for word in words {
      guard let url = URL(string: word), let scheme = url.scheme, url.host != nil || scheme == "magnet" else {
        return .invalid("not a URL or command: \(word) (try help)")
      }
      urls.append(url)
    }
    return .add(urls)
  }

  private static func position(_ words: [String], usage: String, make: (Int) -> Self) -> Self {
    guard words.count == 1, let number = Int(words[0]), number >= 1 else { return .invalid("usage: \(usage)") }
    return make(number)
  }
}
