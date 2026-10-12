import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// Answers every request with one fixed body, on 127.0.0.1 only, so session tests
/// exercise HTTP without a live network.
final class LoopbackHTTPServer: Sendable {

  // MARK: Lifecycle

  init(body: Data, contentType: String) throws {
    #if os(Linux)
    let listener = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #else
    let listener = socket(AF_INET, SOCK_STREAM, 0)
    #endif
    guard listener >= 0 else { throw ServerError.socket }
    var address = sockaddr_in()
    #if !os(Linux)
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    #endif
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let bound = withUnsafeMutablePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(listener, $0, length) == 0 && listen(listener, 8) == 0 && getsockname(listener, $0, &length) == 0
      }
    }
    guard bound else {
      close(listener)
      throw ServerError.socket
    }
    self.listener = listener
    port = UInt16(bigEndian: address.sin_port)

    let header = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
    let response = Data(header.utf8) + body
    let thread = Thread {
      Self.serve(listener: listener, response: response)
    }
    thread.name = "LoopbackHTTPServer"
    thread.start()
  }

  // MARK: Internal

  /// The ephemeral port the server listens on.
  let port: UInt16

  /// Stops accepting connections.
  func stop() {
    shutdown(listener, Int32(SHUT_RDWR))
    close(listener)
  }

  // MARK: Private

  private enum ServerError: Error {
    case socket
  }

  private let listener: Int32

  private static func serve(listener: Int32, response: Data) {
    while true {
      let client = accept(listener, nil, nil)
      guard client >= 0 else { return }
      // Read the request up to the blank line that ends its headers, then answer.
      var request = [UInt8]()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while !request.reversed().starts(with: Array("\n\r\n\r".utf8)) {
        let count = read(client, &buffer, buffer.count)
        guard count > 0 else { break }
        request += buffer[0 ..< count]
      }
      _ = response.withUnsafeBytes { write(client, $0.baseAddress, $0.count) }
      close(client)
    }
  }

}
