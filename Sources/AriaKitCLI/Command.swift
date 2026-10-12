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
