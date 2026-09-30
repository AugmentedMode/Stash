# Architecture

Stash has two Swift package modules. `StashCore` owns clipboard data, classification,
search, retention, screenshots, and persistence. It uses macOS APIs and is not a
cross-platform library. `Stash` owns the application lifecycle and SwiftUI views.
`StashCore` makes no network requests. The app's only request is Sparkle's daily
update check (`UpdateController`), which fetches `appcast.xml` from GitHub Releases
and is disabled in preview and QA builds.

```text
Sources/
  Stash/
    Application/       App lifecycle, panel construction, keyboard/paste routing,
                       published app state, and monitoring lifecycle
    Features/
      History/         Search, list, rows, previews, actions, rename, footer
      Images/          Image browser and bounded asynchronous preview cache
      Prompts/         Prompt library, editing, field filling, model commands
      Settings/        Welcome and settings views
    Design/            Shared colors, icons, artwork, and text highlighting
    Preview/           Synthetic demo content
    Resources/         Bundled category and service artwork
  StashCore/
    Models/            Clip, ClipKind, SavedPrompt
    Clipboard/         Safe capture/restore, change observation, polling policy
    History/           Deduplication, pin-aware budgets, expiry, filtering
    Screenshots/       File watching and bounded image normalization
    Search/            Reusable tokenized queries and highlight ranges
    Presentation/      Offline link labels and text-style recognition
    Persistence/       Private JSON files and coalesced history writes
Tests/StashCoreTests/   Checks grouped by behavior, plus shared test support
```

## Ownership and execution

`AppDelegate` owns the panel, menu-bar item, global hotkey, and destination app.
`PanelFactory` constructs the native glass/material container. Keyboard routing
and paste delivery live in separate files so window setup stays readable.

`AppModel` coordinates published UI state and feature commands on the main thread.
Its history search cache is invalidated when history, query, category, or pin
filter changes. `MonitoringController` owns timers and system notification tokens.
Sleep, display sleep, and inactive sessions suspend capture independently; Low
Power Mode adjusts the timer without restarting screenshot collection.

`ClipboardObserver` checks the change counter before reading data. Exclusions and
sensitive-type markers are enforced before storing representations. A restored
clip advances the observer so Stash does not capture its own paste.

`ScreenshotObserver` owns a serial utility queue and a filesystem source. Initial
folder contents are skipped. New entries get bounded retries because image bytes
and screenshot metadata can arrive separately. It reads dates once per unseen
entry and sorts only candidates. Generations invalidate cancelled scans and
queued deliveries across stop/restart. Consumers receive clips on the main thread.

`HistoryWriter` retains only the newest queued snapshot and coalesces for at most
one second. Its utility queue serializes encoding and writes; a lock protects
pending snapshots. Flush captures the newest snapshot on that same queue so a
concurrent submission cannot be overwritten by an older flush. Never call flush
from the writer's callbacks. Quit and system sleep flush pending history.

Preview decoding uses ImageIO thumbnails off the main thread. A 48 MB NSCache
stores decoded images, and concurrent requests for a fingerprint/size share a
decode task. UI tasks check cancellation before assigning results.

## Data contracts

- Clip IDs survive deduplication and renaming. Original representations remain
  the paste payload; display labels and inferred link names do not replace it.
- SHA-256 fingerprint encoding is unchanged by the refactor to preserve existing
  histories. Changing it requires a migration strategy and legacy fixtures.
- Pins are exempt from both the 500-item and 200 MB unpinned budgets. The newest
  unpinned prefix is retained; older unpinned clips are removed when a limit is hit.
- Search tokenizes a query once and requires all terms, using localized matching.
- History and prompts retain their existing JSON schemas and file paths. Missing
  files yield empty collections; malformed files throw and remain untouched.
- Storage uses atomic replacement inside an owner-only directory and sets files
  to mode 0600. This is local plaintext JSON, not an encrypted vault.
- A failed history load blocks writes to that file. A transient write failure
  reports an error but permits a later save to recover. Prompt saves publish the
  new collection only after storage succeeds; editor drafts survive failures.
- Session-only clipboard history and explicitly saved prompts have separate
  lifetimes. Demo mode never loads or saves either file.

## Deliberate limits

Core checks exercise data and system adapters, not SwiftUI focus or Accessibility
paste delivery. Screenshot pixel matching still normalizes candidate images on
the caller's thread; moving it off-thread would require preserving insertion and
clipboard ordering. Prompt saves remain synchronous and history loads decode the
whole JSON document. Large pinned collections are intentionally unbounded. Profile
those workloads before choosing a database, background load, or a new cache.
