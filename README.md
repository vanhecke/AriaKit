# AriaKit

Swift bindings to libaria2 and a live terminal downloader built on them.

## The tool

```bash
./Scripts/libaria2.sh && source Scripts/env.sh   # macOS, once per shell
swift run ariakit --dir ~/Downloads               # live list; type or paste URLs
printf '%s\n' https://example.com/a.iso | swift run ariakit   # piped: exits when done
```

Sources: http(s), ftp, sftp, and magnet URLs, URLs to `.torrent` / Metalink files, and
local `.torrent`, `.metalink`, or `.meta4` files (drag them in; escaped spaces work).
A magnet or `.torrent` URL shows its content as a follow-up row (`#2 continues #1`).
Torrents stop when downloaded; pass `--seed` to keep seeding (aria2 default: ratio 1.0).

Type `help` in the tool for `pause <n>`, `resume <n>`, `rm <n>`, `ls`, `quit`.

## The library

```swift
import AriaKit

let session = try await AriaSession(options: ["dir": "/tmp"])
let id = try await session.add([URL(string: "https://example.com/a.iso")!])
// Also: session.addTorrent(fileURL), session.addMetalink(fileURL). A magnet or .torrent URL
// completes once its metadata arrives; the content continues as status.followedBy.
for await event in session.events where event.id == id && event.kind == .completed { break }
await session.shutdown()
```

Requirements for a package that depends on AriaKit:

- libaria2 on the build machine. macOS: `./Scripts/libaria2.sh --prefix /usr/local`
  (or any prefix on `PKG_CONFIG_PATH`; deps `brew install pkgconf c-ares libssh2 sqlite openssl@3`).
  Linux: `apt install libaria2-0-dev`.
- `swiftSettings: [.interoperabilityMode(.Cxx)]` on every target that imports AriaKit.
  Swift rejects a C++-interop module in a client that does not enable it.

## Development

```bash
./Scripts/ci.sh                       # lint, format-check, tests, issues
source Scripts/env.sh && xed .        # Xcode needs PKG_CONFIG_PATH to find libaria2
```

There is no committed `.xcodeproj`. See [AGENTS.md](AGENTS.md).

## License

GPL-2.0-or-later (links libaria2). See [LICENSE](LICENSE).
