import Configuration

/// Process configuration via `apple/swift-configuration`.
public struct AppConfig: Sendable {
  public init(reader: ConfigReader = ConfigReader(provider: EnvironmentVariablesProvider())) {
    version = reader.string(forKey: "APP_VERSION", default: "0.0.0")
    downloadDirectory = reader.string(forKey: "ARIAKIT_DIR")
  }

  /// Version string printed by `--version`.
  public let version: String
  /// Default download directory (`ARIAKIT_DIR`); `nil` when unset.
  public let downloadDirectory: String?
}
