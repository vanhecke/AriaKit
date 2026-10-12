# AriaKit

Swift bindings to libaria2 and a live terminal downloader built on them.

- **AriaKit**: a Swift library that runs aria2's download engine in-process
  through Swift C++ interop. Async API, event stream, one engine thread.
- **ariakit**: a terminal downloader. Add URLs or torrent files while it runs;
  each one starts right away.

Protocols: HTTP(S), FTP, SFTP, BitTorrent (magnet links and `.torrent` files),
and Metalink.

## The tool

```bash
./Scripts/libaria2.sh && source Scripts/env.sh   # macOS, once per shell (see Requirements)
swift run ariakit --dir ~/Downloads              # live list; type or paste URLs
swift run ariakit https://example.com/a.iso      # start with downloads given as arguments
cat urls.txt | swift run ariakit                 # piped: one source per line, exits when done
```

In a terminal, `ariakit` shows a live list redrawn twice a second, with an
input line at the bottom:

```
#1 [##########----------]  50%  500.0 MiB / 1000.0 MiB  5.1 MiB/s  active  1000mb.bin
#2 [####################] 100%  20.8 KiB / 20.8 KiB    complete  [METADATA]Big+Buck+Bunny
#3 [##------------------]  12%  31.6 MiB / 263.6 MiB  2.2 MiB/s  active  Big Buck Bunny
```

When stdin is not a terminal, it reads one command per line, writes events
to stdout and errors to stderr, and exits once input ends and every
download has finished.

### Sources

| You give | What happens |
|---|---|
| `http(s)://`, `ftp://`, `sftp://` URL | Downloads the file. |
| `magnet:` link | Fetches the metadata, then the content continues as a new row (`#2 continues #1`). |
| URL to a `.torrent` or Metalink file | Fetches that file, then its content continues as new rows. |
| Local `.torrent`, `.metalink`, `.meta4` file | Starts what it describes. Paths may use `~` or `file://`. |

Several sources on one line become separate downloads. When typing or
pasting a path, escape spaces with a backslash (`My\ File.torrent`), which is
what a terminal does when you drag a file in. Command-line arguments need no
escaping.

### Commands

| Command | Does |
|---|---|
| `<source> […]` or `add <source> […]` | Add downloads |
| `pause <n>` / `resume <n>` | Pause or resume download `#n` |
| `rm <n>` | Remove download `#n` |
| `ls` | List downloads |
| `help` | Show the commands |
| `quit`, Ctrl-D, Ctrl-C | Stop all downloads and exit |

### Options

| Option | Default | Meaning |
|---|---|---|
| `-d, --dir <dir>` | `$ARIAKIT_DIR`, else the current directory | Where files are saved |
| `-c, --connections <n>` | 4 (1–16) | Connections per server for each download. Parts are at least 20 MB, so smaller files use fewer. |
| `-m, --max-concurrent <n>` | 5 | Downloads running at once; the rest wait |
| `--seed` | off | Keep seeding finished torrents until share ratio 1.0. Without it, a torrent finishes once downloaded. |
| `-v, --version` | | Print the version |

Failures say what went wrong, for example
`#1 __down failed: server returned an HTTP error or unexpected response (e.g. 403, 5xx) (aria2 error 22)`.
libaria2 reports only the error code, so the exact HTTP status is not shown.

Exit status: 0 when every download succeeded, 1 if any failed, 64 for a bad
option.

aria2 reserves a file's full size on disk when its download starts. A
stopped download leaves a `.aria2` control file next to the partial file;
adding the same source again with the same `--dir` resumes where it stopped.

## The library

```swift
import AriaKit

let session = try await AriaSession(options: [
  "dir": "/tmp",
  "max-connection-per-server": "4",
  "split": "4",
])

let id = try await session.add([URL(string: "https://example.com/a.iso")!])
for await event in session.events where event.id == id {
  if event.kind == .completed || event.kind == .failed { break }
}

let status = try await session.status(of: id)
print(status.state, status.progress ?? 0, status.errorDescription ?? "ok")
await session.shutdown()
```

| API | Does |
|---|---|
| `AriaSession(options:)` | Starts the engine. Options are aria2's, without the leading `--`. |
| `add(_ urls:options:)` | Adds one file from one or more mirrors, or a magnet link |
| `addTorrent(_:options:)` | Adds a local `.torrent` file |
| `addMetalink(_:options:)` | Adds every file in a local Metalink; returns one ID per file |
| `pause(_:)`, `resume(_:)`, `remove(_:)` | Control a download |
| `status(of:)` | Snapshot: state, sizes, speeds, files, error code and `errorDescription` |
| `events` | `AsyncStream` of started / paused / stopped / completed / failed / BitTorrent-completed |
| `shutdown()` | Stops all downloads, saves control files, ends the session |

A magnet link or a URL to a `.torrent` or Metalink file completes once its
metadata is fetched. The real content continues as new downloads, listed in
`status.followedBy`; each of those points back through `status.following`.

Things to know:

- **One session per process.** libaria2 allows only one; a second
  `AriaSession` throws `AriaError.sessionAlreadyActive`. A new session can
  start after `shutdown()`.
- **SIGPIPE is ignored** for the whole process once a session starts, unless
  the app installed its own handler. Without that, a server closing a
  connection mid-transfer would kill the process.
- **Latency.** Calls run on aria2's thread. A call made right after another
  one runs immediately. The first call after the engine has been idle (no
  network activity) can wait up to 1 s, because aria2's event loop sleeps in
  1 s steps and cannot be woken from outside.

### Requirements for a package that depends on AriaKit

- libaria2 on the build machine.
  - macOS: Homebrew's `aria2` does not include the library. Build it with
    `./Scripts/libaria2.sh --prefix /usr/local` (or any prefix on
    `PKG_CONFIG_PATH`); dependencies:
    `brew install pkgconf c-ares libssh2 sqlite openssl@3`.
  - Linux: `apt install libaria2-0-dev`.
- `swiftSettings: [.interoperabilityMode(.Cxx)]` on every target that imports
  AriaKit. Swift rejects a module built with C++ interop in a client that
  does not enable it.
- macOS 15 or later.

## Development

```bash
./Scripts/libaria2.sh                 # builds libaria2 into .deps/ (macOS, ~75 s, once)
./Scripts/ci.sh                       # lint, format-check, tests, issues
source Scripts/env.sh && xed .        # Xcode needs PKG_CONFIG_PATH to find libaria2
```

Tests never use the internet. Network tests talk to a small HTTP server on
127.0.0.1 inside the test. There is no committed `.xcodeproj`. See
[AGENTS.md](AGENTS.md).

## License

GPL-2.0-or-later, because AriaKit links libaria2. See [LICENSE](LICENSE).
