import Foundation

/// One line of input to the downloader.
enum ReplCommand: Equatable {
  /// Each source becomes its own download (a Metalink may become several).
  case add([Source])
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

  /// Something to download.
  enum Source: Equatable {
    /// HTTP(S), FTP, SFTP, or magnet URL. Also a URL to a `.torrent` or Metalink file.
    case url(URL)
    /// Local `.torrent` file.
    case torrent(URL)
    /// Local `.metalink` / `.meta4` file.
    case metalink(URL)

    /// The URL or file the user gave.
    var location: URL {
      switch self {
      case .url(let url),
           .torrent(let url),
           .metalink(let url): url
      }
    }
  }

  static let usage = """
    Commands (type while downloads run):
      <source> […]     add downloads (also: add <source>…). A source is an http(s),
                       ftp, sftp, or magnet URL, or a local .torrent / .metalink /
                       .meta4 file. Escape spaces in paths with a backslash.
      pause <n>        pause download #n
      resume <n>       resume download #n
      rm <n>           remove download #n
      ls               list downloads
      help             show this help
      quit             stop and exit (also Ctrl-D, Ctrl-C)
    """

  static func parse(_ line: String) -> Self {
    let words = words(line)
    guard let first = words.first else { return .empty }
    let rest = Array(words.dropFirst())
    switch first.lowercased() {
    case "add": return rest.isEmpty ? .invalid("add needs at least one URL or file") : add(rest)
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
    default: return add(words)
    }
  }

  /// Sources given as whole words, e.g. command-line arguments (spaces need no escaping).
  static func add(_ words: [String]) -> Self {
    var sources = [Source]()
    for word in words {
      guard let source = source(word) else {
        return .invalid("not a URL, .torrent / .metalink file, or command: \(word) (try help)")
      }
      sources.append(source)
    }
    return .add(sources)
  }

  // MARK: Private

  /// Splits on whitespace; a backslash makes the next character literal (as a terminal
  /// writes a dragged-in path with spaces).
  private static func words(_ line: String) -> [String] {
    var words = [String]()
    var current = ""
    var inWord = false
    var escaped = false
    for character in line {
      if escaped {
        current.append(character)
        escaped = false
      } else if character == "\\" {
        escaped = true
        inWord = true
      } else if character.isWhitespace {
        if inWord {
          words.append(current)
          current = ""
          inWord = false
        }
      } else {
        current.append(character)
        inWord = true
      }
    }
    if inWord {
      words.append(current)
    }
    return words
  }

  private static func source(_ word: String) -> Source? {
    if
      let url = URL(string: word),
      let scheme = url.scheme?.lowercased(),
      scheme != "file",
      url.host != nil || scheme == "magnet"
    {
      return .url(url)
    }
    let file = word.lowercased().hasPrefix("file://")
      ? URL(string: word)
      : URL(fileURLWithPath: NSString(string: word).expandingTildeInPath)
    guard let file else { return nil }
    switch file.pathExtension.lowercased() {
    case "torrent": return .torrent(file)
    case "metalink",
         "meta4": return .metalink(file)
    default: return nil
    }
  }

  private static func position(_ words: [String], usage: String, make: (Int) -> Self) -> Self {
    guard words.count == 1, let number = Int(words[0]), number >= 1 else { return .invalid("usage: \(usage)") }
    return make(number)
  }
}
