import Foundation

/// Raw stdin bytes, read on a dedicated thread so blocking `read(2)` never
/// ties up the concurrency pool. Finishes at EOF.
enum InputReader {
  static func chunks() -> AsyncStream<[UInt8]> {
    let (stream, continuation) = AsyncStream.makeStream(of: [UInt8].self)
    let thread = Thread {
      var buffer = [UInt8](repeating: 0, count: 4096)
      while true {
        let count = read(STDIN_FILENO, &buffer, buffer.count)
        guard count > 0 else { break }
        continuation.yield(Array(buffer[0 ..< count]))
      }
      continuation.finish()
    }
    thread.name = "ariakit.stdin"
    thread.start()
    return stream
  }
}
