#include "AriaShim.h"

#include <aria2/aria2.h>

#include <signal.h>
#include <algorithm>
#include <cstdlib>
#include <exception>
#include <mutex>
#include <string>
#include <vector>

struct AriaShimOptions {
  aria2::KeyVals values;
};

struct AriaShimURIs {
  std::vector<std::string> values;
};

struct AriaShimSnapshot {
  int status;
  std::int64_t totalLength;
  std::int64_t completedLength;
  int downloadSpeed;
  int uploadSpeed;
  int errorCode;
  std::string dir;
  std::vector<std::string> files;
  std::uint64_t following;
  std::vector<std::uint64_t> followedBy;
};

namespace {

struct Bridge {
  AriaShimEventCallback callback;
  void* context;
};

int trampoline(aria2::Session*, aria2::DownloadEvent event, aria2::A2Gid gid, void* userData) {
  auto* bridge = static_cast<Bridge*>(userData);
  bridge->callback(static_cast<int>(event), gid, bridge->context);
  return 0;
}

// One session per process (libaria2 rule), so one bridge.
Bridge* currentBridge = nullptr;

// AriaShimSession is never defined: it is the aria2::Session under another name.
aria2::Session* unwrap(AriaShimSession* session) { return reinterpret_cast<aria2::Session*>(session); }

// C++ exceptions must not unwind into Swift: run `body`, or return `fallback` if it throws.
template <typename Result, typename Body>
Result guarded(Result fallback, Body body) noexcept {
  try {
    return body();
  } catch (...) {
    return fallback;
  }
}

// libaria2's add functions only reserve the download; the engine notices on its next
// iteration, after a poll that blocks up to 1 s, and starts it one refresh cycle (1 s)
// later. Pausing a still-waiting download only sets a flag plus a zero refresh interval;
// unpausing clears the flag. Net effect: no state change, no event, and the next
// iteration neither blocks nor waits for the refresh cycle.
void startPromptly(aria2::Session* session, aria2::A2Gid gid) {
  if (aria2::pauseDownload(session, gid, false) == 0) {
    aria2::unpauseDownload(session, gid);
  }
}

// aria2c ignores SIGPIPE only when it installs its own signal handlers, which sessionNew
// skips (useSignalHandler = false). Without this, a peer or server closing a socket
// mid-write kills the host process. A handler the host installed is left alone.
void ignoreSigpipeIfDefault() {
#ifdef SIGPIPE
  struct sigaction current {};
  if (sigaction(SIGPIPE, nullptr, &current) == 0 && current.sa_handler == SIG_DFL) {
    signal(SIGPIPE, SIG_IGN);
  }
#endif
}

} // namespace

extern "C" {

int ariashim_libraryInit(void) {
  // libaria2 crashes if re-initialized after libraryDeinit, so init once and never deinit.
  static std::once_flag once;
  static int code = 0;
  std::call_once(once, [] {
    ignoreSigpipeIfDefault();
    code = guarded(-1, [] { return aria2::libraryInit(); });
  });
  return code;
}

AriaShimOptions* ariashim_optionsNew(void) { return new AriaShimOptions; }

void ariashim_optionsAppend(AriaShimOptions* options, const char* key, const char* value) {
  options->values.emplace_back(key, value);
}

void ariashim_optionsFree(AriaShimOptions* options) { delete options; }

AriaShimURIs* ariashim_urisNew(void) { return new AriaShimURIs; }

void ariashim_urisAppend(AriaShimURIs* uris, const char* uri) { uris->values.emplace_back(uri); }

void ariashim_urisFree(AriaShimURIs* uris) { delete uris; }

AriaShimSession* ariashim_sessionNew(
    const AriaShimOptions* options, AriaShimEventCallback callback, void* context) {
  auto* bridge = new Bridge{callback, context};
  aria2::SessionConfig config;
  config.keepRunning = true;
  config.useSignalHandler = false;
  config.downloadEventCallback = trampoline;
  config.userData = bridge;
  aria2::Session* session =
      guarded<aria2::Session*>(nullptr, [&] { return aria2::sessionNew(options->values, config); });
  if (session == nullptr) {
    delete bridge;
    return nullptr;
  }
  currentBridge = bridge;
  return reinterpret_cast<AriaShimSession*>(session);
}

int ariashim_sessionFinal(AriaShimSession* session) {
  int code = guarded(-1, [&] { return aria2::sessionFinal(unwrap(session)); });
  delete currentBridge;
  currentBridge = nullptr;
  return code;
}

int ariashim_runOnce(AriaShimSession* session) {
  return guarded(-1, [&] { return aria2::run(unwrap(session), aria2::RUN_ONCE); });
}

int ariashim_shutdown(AriaShimSession* session, bool force) {
  return guarded(-1, [&] { return aria2::shutdown(unwrap(session), force); });
}

int ariashim_addUri(
    AriaShimSession* session, const AriaShimURIs* uris, const AriaShimOptions* options, std::uint64_t* gid) {
  return guarded(-1, [&] {
    int code = aria2::addUri(unwrap(session), gid, uris->values, options->values);
    if (code == 0) {
      startPromptly(unwrap(session), *gid);
    }
    return code;
  });
}

int ariashim_addTorrent(
    AriaShimSession* session, const char* torrentFile, const AriaShimOptions* options, std::uint64_t* gid) {
  return guarded(-1, [&] {
    int code = aria2::addTorrent(unwrap(session), gid, torrentFile, options->values);
    if (code == 0) {
      startPromptly(unwrap(session), *gid);
    }
    return code;
  });
}

int ariashim_addMetalink(
    AriaShimSession* session,
    const char* metalinkFile,
    const AriaShimOptions* options,
    std::uint64_t** gids,
    int* count) {
  *gids = nullptr;
  *count = 0;
  return guarded(-1, [&] {
    std::vector<aria2::A2Gid> added;
    int code = aria2::addMetalink(unwrap(session), &added, metalinkFile, options->values);
    for (aria2::A2Gid gid : added) {
      startPromptly(unwrap(session), gid);
    }
    if (!added.empty()) {
      *gids = static_cast<std::uint64_t*>(std::malloc(added.size() * sizeof(std::uint64_t)));
      if (*gids == nullptr) {
        return -1;
      }
      std::copy(added.begin(), added.end(), *gids);
      *count = static_cast<int>(added.size());
    }
    return code;
  });
}

int ariashim_removeDownload(AriaShimSession* session, std::uint64_t gid, bool force) {
  return guarded(-1, [&] { return aria2::removeDownload(unwrap(session), gid, force); });
}

int ariashim_pauseDownload(AriaShimSession* session, std::uint64_t gid, bool force) {
  return guarded(-1, [&] { return aria2::pauseDownload(unwrap(session), gid, force); });
}

int ariashim_unpauseDownload(AriaShimSession* session, std::uint64_t gid) {
  return guarded(-1, [&] { return aria2::unpauseDownload(unwrap(session), gid); });
}

AriaShimSnapshot* ariashim_snapshotNew(AriaShimSession* session, std::uint64_t gid) {
  return guarded<AriaShimSnapshot*>(nullptr, [&]() -> AriaShimSnapshot* {
    aria2::DownloadHandle* handle = aria2::getDownloadHandle(unwrap(session), gid);
    if (handle == nullptr) {
      return nullptr;
    }
    auto* result = new AriaShimSnapshot{};
    result->status = static_cast<int>(handle->getStatus());
    result->totalLength = handle->getTotalLength();
    result->completedLength = handle->getCompletedLength();
    result->downloadSpeed = handle->getDownloadSpeed();
    result->uploadSpeed = handle->getUploadSpeed();
    result->errorCode = handle->getErrorCode();
    result->dir = handle->getDir();
    for (const aria2::FileData& file : handle->getFiles()) {
      result->files.push_back(file.path);
    }
    result->following = handle->getFollowing();
    const std::vector<aria2::A2Gid>& followedBy = handle->getFollowedBy();
    result->followedBy.assign(followedBy.begin(), followedBy.end());
    aria2::deleteDownloadHandle(handle);
    return result;
  });
}

void ariashim_snapshotFree(AriaShimSnapshot* snapshot) { delete snapshot; }

int ariashim_snapshotStatus(const AriaShimSnapshot* snapshot) { return snapshot->status; }

std::int64_t ariashim_snapshotTotalLength(const AriaShimSnapshot* snapshot) { return snapshot->totalLength; }

std::int64_t ariashim_snapshotCompletedLength(const AriaShimSnapshot* snapshot) {
  return snapshot->completedLength;
}

int ariashim_snapshotDownloadSpeed(const AriaShimSnapshot* snapshot) { return snapshot->downloadSpeed; }

int ariashim_snapshotUploadSpeed(const AriaShimSnapshot* snapshot) { return snapshot->uploadSpeed; }

int ariashim_snapshotErrorCode(const AriaShimSnapshot* snapshot) { return snapshot->errorCode; }

const char* ariashim_snapshotDirectory(const AriaShimSnapshot* snapshot) { return snapshot->dir.c_str(); }

int ariashim_snapshotFileCount(const AriaShimSnapshot* snapshot) {
  return static_cast<int>(snapshot->files.size());
}

const char* ariashim_snapshotFile(const AriaShimSnapshot* snapshot, int index) {
  return snapshot->files[index].c_str();
}

std::uint64_t ariashim_snapshotFollowing(const AriaShimSnapshot* snapshot) { return snapshot->following; }

int ariashim_snapshotFollowedByCount(const AriaShimSnapshot* snapshot) {
  return static_cast<int>(snapshot->followedBy.size());
}

std::uint64_t ariashim_snapshotFollowedBy(const AriaShimSnapshot* snapshot, int index) {
  return snapshot->followedBy[index];
}

} // extern "C"
