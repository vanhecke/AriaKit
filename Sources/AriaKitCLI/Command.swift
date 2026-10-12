import ArgumentParser
import AriaKit
import Foundation

/// Swift bindings to libaria2 and a live terminal downloader built on them.
@main
struct AriaKitCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ariakit",
    abstract: "Download files with libaria2. Type or pipe URLs and files while it runs; each starts right away.",
    discussion: ReplCommand.usage,
  )

  @Flag(name: .shortAndLong, help: "Print the version and exit.")
  var version = false

  @Option(name: .shortAndLong, help: "Directory to save files in. Default: $ARIAKIT_DIR, else the current directory.")
  var dir: String?

  @Option(name: .shortAndLong, help: "Maximum downloads running at once.")
  var maxConcurrent = 5

  @Option(
    name: .shortAndLong,
    help: "Connections per server for each download (1-16). Each part is at least 20 MB, so small files use fewer.",
  )
  var connections = 4

  @Flag(
    help: "Keep seeding finished torrents until share ratio 1.0 (aria2's default). Without it, a torrent finishes once downloaded."
  )
  var seed = false

  @Argument(help: "URLs or .torrent / .metalink files to start downloading right away.")
  var urls = [String]()

  func validate() throws {
    guard maxConcurrent >= 1 else {
      throw ValidationError("--max-concurrent must be at least 1.")
    }
    // aria2 caps max-connection-per-server at 16.
    guard (1 ... 16).contains(connections) else {
      throw ValidationError("--connections must be between 1 and 16.")
    }
  }

  mutating func run() async throws {
    let config = AppConfig()
    if version {
      FileHandle.standardOutput.write(Data("ariakit \(config.version)\n".utf8))
      return
    }
    let directory = dir ?? config.downloadDirectory ?? FileManager.default.currentDirectoryPath
    var options = [
      "dir": directory,
      "max-concurrent-downloads": String(maxConcurrent),
      // aria2 opens at most max-connection-per-server per server; split is how many
      // parts a file may be cut into (each at least min-split-size, 20 MB by default).
      "max-connection-per-server": String(connections),
      "split": String(connections),
    ]
    if !seed {
      options["seed-time"] = "0"
    }
    let session = try await AriaSession(options: options)
    let interactive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    let succeeded = await Console(session: session, interactive: interactive).run(initialInput: urls)
    if !succeeded {
      throw ExitCode.failure
    }
  }
}
