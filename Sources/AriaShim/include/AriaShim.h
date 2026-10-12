#pragma once

#include <stdbool.h>
#include <stdint.h>

/// C surface over libaria2, so Swift imports it without C++ interop and neither
/// AriaKit nor its clients need `.interoperabilityMode(.Cxx)`. The C++ lives in
/// AriaShim.cpp. Handles are opaque; whoever creates one frees it.

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang assume_nonnull begin

/// An `aria2::Session`.
typedef struct AriaShimSession AriaShimSession;
/// Key-value aria2 options (`aria2::KeyVals`).
typedef struct AriaShimOptions AriaShimOptions;
/// A list of URIs.
typedef struct AriaShimURIs AriaShimURIs;
/// Snapshot of one download.
typedef struct AriaShimSnapshot AriaShimSnapshot;

/// Called on the session thread for every download event.
typedef void (*AriaShimEventCallback)(int event, uint64_t gid, void* _Nullable context);

/// Initializes libaria2 once per process; later calls return the first result.
int ariashim_libraryInit(void);

AriaShimOptions* ariashim_optionsNew(void);
void ariashim_optionsAppend(AriaShimOptions* options, const char* key, const char* value);
void ariashim_optionsFree(AriaShimOptions* options);

AriaShimURIs* ariashim_urisNew(void);
void ariashim_urisAppend(AriaShimURIs* uris, const char* uri);
void ariashim_urisFree(AriaShimURIs* uris);

/// Returns NULL if aria2 rejects the options.
AriaShimSession* _Nullable ariashim_sessionNew(
    const AriaShimOptions* options, AriaShimEventCallback callback, void* _Nullable context);
int ariashim_sessionFinal(AriaShimSession* session);
/// Runs one event-loop iteration. Returns 1 while work remains, 0 when done, -1 on error.
int ariashim_runOnce(AriaShimSession* session);
int ariashim_shutdown(AriaShimSession* session, bool force);

/// Each add returns 0 on success.
int ariashim_addUri(
    AriaShimSession* session, const AriaShimURIs* uris, const AriaShimOptions* options, uint64_t* gid);
int ariashim_addTorrent(
    AriaShimSession* session, const char* torrentFile, const AriaShimOptions* options, uint64_t* gid);
/// Sets `*gids` to a `malloc`ed array of `*count` GIDs, one per file; release it with `free`.
int ariashim_addMetalink(
    AriaShimSession* session,
    const char* metalinkFile,
    const AriaShimOptions* options,
    uint64_t* _Nullable* _Nonnull gids,
    int* count);
int ariashim_removeDownload(AriaShimSession* session, uint64_t gid, bool force);
int ariashim_pauseDownload(AriaShimSession* session, uint64_t gid, bool force);
int ariashim_unpauseDownload(AriaShimSession* session, uint64_t gid);

/// Returns NULL when aria2 no longer knows the GID. Release with `ariashim_snapshotFree`.
AriaShimSnapshot* _Nullable ariashim_snapshotNew(AriaShimSession* session, uint64_t gid);
void ariashim_snapshotFree(AriaShimSnapshot* snapshot);
int ariashim_snapshotStatus(const AriaShimSnapshot* snapshot);
int64_t ariashim_snapshotTotalLength(const AriaShimSnapshot* snapshot);
int64_t ariashim_snapshotCompletedLength(const AriaShimSnapshot* snapshot);
int ariashim_snapshotDownloadSpeed(const AriaShimSnapshot* snapshot);
int ariashim_snapshotUploadSpeed(const AriaShimSnapshot* snapshot);
int ariashim_snapshotErrorCode(const AriaShimSnapshot* snapshot);
const char* ariashim_snapshotDirectory(const AriaShimSnapshot* snapshot);
int ariashim_snapshotFileCount(const AriaShimSnapshot* snapshot);
const char* ariashim_snapshotFile(const AriaShimSnapshot* snapshot, int index);
/// GID this download continues (e.g. a torrent fetched by URL), 0 if none.
uint64_t ariashim_snapshotFollowing(const AriaShimSnapshot* snapshot);
/// GIDs started from this download's result (torrent content, Metalink files).
int ariashim_snapshotFollowedByCount(const AriaShimSnapshot* snapshot);
uint64_t ariashim_snapshotFollowedBy(const AriaShimSnapshot* snapshot, int index);

#pragma clang assume_nonnull end

#ifdef __cplusplus
} // extern "C"
#endif
