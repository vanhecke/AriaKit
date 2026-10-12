#pragma once

#include <aria2/aria2.h>

#include <cstdint>
#include <string>
#include <vector>

/// Swift-friendly surface over libaria2. Swift never touches the abstract
/// `aria2::DownloadHandle` or default arguments; it calls these functions.
namespace ariashim {

using StringList = std::vector<std::string>;
using KeyVals = aria2::KeyVals;

/// Called on the session thread for every download event.
using EventCallback = void (*)(int event, std::uint64_t gid, void* context);

/// Result of `addUri`: `code` is 0 on success.
struct AddResult {
  int code;
  std::uint64_t gid;
};

/// Result of `addMetalink`: `code` is 0 on success; one GID per file.
struct AddManyResult {
  int code;
  std::vector<std::uint64_t> gids;
};

/// Snapshot of one download. `found` is false when aria2 no longer knows the GID.
struct Snapshot {
  bool found;
  int status;
  std::int64_t totalLength;
  std::int64_t completedLength;
  int downloadSpeed;
  int uploadSpeed;
  int errorCode;
  std::string dir;
  StringList files;
  /// GID this download continues (e.g. a torrent fetched by URL), 0 if none.
  std::uint64_t following;
  /// GIDs started from this download's result (torrent content, Metalink files).
  std::vector<std::uint64_t> followedBy;
};

/// Initializes libaria2 once per process; later calls return the first result.
int libraryInit();

void appendOption(KeyVals& options, const char* key, const char* value);
void appendString(StringList& list, const char* value);

aria2::Session* sessionNew(const KeyVals& options, EventCallback callback, void* context);
int sessionFinal(aria2::Session* session);
/// Runs one event-loop iteration. Returns 1 while work remains, 0 when done, -1 on error.
int runOnce(aria2::Session* session);
int shutdown(aria2::Session* session, bool force);

AddResult addUri(aria2::Session* session, const StringList& uris, const KeyVals& options);
AddResult addTorrent(aria2::Session* session, const char* torrentFile, const KeyVals& options);
AddManyResult addMetalink(aria2::Session* session, const char* metalinkFile, const KeyVals& options);
int addedCount(const AddManyResult& result);
std::uint64_t addedGid(const AddManyResult& result, int index);
int removeDownload(aria2::Session* session, std::uint64_t gid, bool force);
int pauseDownload(aria2::Session* session, std::uint64_t gid, bool force);
int unpauseDownload(aria2::Session* session, std::uint64_t gid);
Snapshot snapshot(aria2::Session* session, std::uint64_t gid);

const char* snapshotDirectory(const Snapshot& snapshot);
int snapshotFileCount(const Snapshot& snapshot);
const char* snapshotFile(const Snapshot& snapshot, int index);
int snapshotFollowedByCount(const Snapshot& snapshot);
std::uint64_t snapshotFollowedBy(const Snapshot& snapshot, int index);

} // namespace ariashim

