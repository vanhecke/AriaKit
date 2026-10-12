#include "AriaShim.h"

#include <exception>
#include <mutex>

namespace ariashim {

namespace {

struct Bridge {
  EventCallback callback;
  void* context;
};

int trampoline(aria2::Session*, aria2::DownloadEvent event, aria2::A2Gid gid, void* userData) {
  auto* bridge = static_cast<Bridge*>(userData);
  bridge->callback(static_cast<int>(event), gid, bridge->context);
  return 0;
}

// One session per process (libaria2 rule), so one bridge.
Bridge* currentBridge = nullptr;

// C++ exceptions must not unwind into Swift: run `body`, or return `fallback` if it throws.
template <typename Result, typename Body>
Result guarded(Result fallback, Body body) noexcept {
  try {
    return body();
  } catch (...) {
    return fallback;
  }
}

} // namespace

int libraryInit() {
  // libaria2 crashes if re-initialized after libraryDeinit, so init once and never deinit.
  static std::once_flag once;
  static int code = 0;
  std::call_once(once, [] { code = guarded(-1, [] { return aria2::libraryInit(); }); });
  return code;
}

void appendOption(KeyVals& options, const char* key, const char* value) {
  options.emplace_back(key, value);
}

void appendString(StringList& list, const char* value) { list.emplace_back(value); }

aria2::Session* sessionNew(const KeyVals& options, EventCallback callback, void* context) {
  auto* bridge = new Bridge{callback, context};
  aria2::SessionConfig config;
  config.keepRunning = true;
  config.useSignalHandler = false;
  config.downloadEventCallback = trampoline;
  config.userData = bridge;
  aria2::Session* session =
      guarded<aria2::Session*>(nullptr, [&] { return aria2::sessionNew(options, config); });
  if (session == nullptr) {
    delete bridge;
    return nullptr;
  }
  currentBridge = bridge;
  return session;
}

int sessionFinal(aria2::Session* session) {
  int code = guarded(-1, [&] { return aria2::sessionFinal(session); });
  delete currentBridge;
  currentBridge = nullptr;
  return code;
}

int runOnce(aria2::Session* session) {
  return guarded(-1, [&] { return aria2::run(session, aria2::RUN_ONCE); });
}

int shutdown(aria2::Session* session, bool force) {
  return guarded(-1, [&] { return aria2::shutdown(session, force); });
}

AddResult addUri(aria2::Session* session, const StringList& uris, const KeyVals& options) {
  return guarded(AddResult{-1, 0}, [&] {
    aria2::A2Gid gid = 0;
    int code = aria2::addUri(session, &gid, uris, options);
    return AddResult{code, gid};
  });
}

AddResult addTorrent(aria2::Session* session, const char* torrentFile, const KeyVals& options) {
  return guarded(AddResult{-1, 0}, [&] {
    aria2::A2Gid gid = 0;
    int code = aria2::addTorrent(session, &gid, torrentFile, options);
    return AddResult{code, gid};
  });
}

AddManyResult addMetalink(aria2::Session* session, const char* metalinkFile, const KeyVals& options) {
  return guarded(AddManyResult{-1, {}}, [&] {
    std::vector<aria2::A2Gid> gids;
    int code = aria2::addMetalink(session, &gids, metalinkFile, options);
    return AddManyResult{code, std::vector<std::uint64_t>(gids.begin(), gids.end())};
  });
}

int addedCount(const AddManyResult& result) { return static_cast<int>(result.gids.size()); }

std::uint64_t addedGid(const AddManyResult& result, int index) { return result.gids[index]; }

int removeDownload(aria2::Session* session, std::uint64_t gid, bool force) {
  return guarded(-1, [&] { return aria2::removeDownload(session, gid, force); });
}

int pauseDownload(aria2::Session* session, std::uint64_t gid, bool force) {
  return guarded(-1, [&] { return aria2::pauseDownload(session, gid, force); });
}

int unpauseDownload(aria2::Session* session, std::uint64_t gid) {
  return guarded(-1, [&] { return aria2::unpauseDownload(session, gid); });
}

Snapshot snapshot(aria2::Session* session, std::uint64_t gid) {
  return guarded(Snapshot{}, [&] {
    Snapshot result{};
    aria2::DownloadHandle* handle = aria2::getDownloadHandle(session, gid);
    if (handle == nullptr) {
      return result;
    }
    result.found = true;
    result.status = static_cast<int>(handle->getStatus());
    result.totalLength = handle->getTotalLength();
    result.completedLength = handle->getCompletedLength();
    result.downloadSpeed = handle->getDownloadSpeed();
    result.uploadSpeed = handle->getUploadSpeed();
    result.errorCode = handle->getErrorCode();
    result.dir = handle->getDir();
    for (const aria2::FileData& file : handle->getFiles()) {
      result.files.push_back(file.path);
    }
    result.following = handle->getFollowing();
    const std::vector<aria2::A2Gid>& followedBy = handle->getFollowedBy();
    result.followedBy.assign(followedBy.begin(), followedBy.end());
    aria2::deleteDownloadHandle(handle);
    return result;
  });
}

const char* snapshotDirectory(const Snapshot& snapshot) { return snapshot.dir.c_str(); }

int snapshotFileCount(const Snapshot& snapshot) { return static_cast<int>(snapshot.files.size()); }

const char* snapshotFile(const Snapshot& snapshot, int index) { return snapshot.files[index].c_str(); }

int snapshotFollowedByCount(const Snapshot& snapshot) { return static_cast<int>(snapshot.followedBy.size()); }

std::uint64_t snapshotFollowedBy(const Snapshot& snapshot, int index) { return snapshot.followedBy[index]; }

} // namespace ariashim
