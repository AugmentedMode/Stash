# Stash UX review

The primary journey is copy → summon → find → paste → continue working. The palette keeps search, categories, a stable selection, and keyboard help visible. Native Liquid Glass is used on macOS 26 with a material fallback on older systems.

| Journey | Implemented behavior | Verification |
| --- | --- | --- |
| First launch | Explicit Start collecting action; explains local storage and retention; existing clipboard is not imported | Code reviewed; core startup capture check passes |
| Collect | New copies only; supported rich text, images and files; deduplication; exclusions | Isolated real-pasteboard checks pass |
| Summon/reopen | Menu bar or ⌘⇧V; focus search; clear old query/filter | Native reopen observed; global physical shortcut still needs manual acceptance |
| Find | Multi-term search, categories, pins, keyboard selection | Core search checks and native search pass |
| Category navigation | All → Pinned → Text → Links → Images → Files → remaining types; Option-arrows work during search | Native All → Pinned and core filters checked |
| Empty results | Distinct first-copy, paused, empty-category, empty-pins and unmatched-search states; Show all clips recovery | Native empty Images and recovery checked |
| Preview | Inline full content, source/date, pin and actions; Escape returns to results | Native search → preview → Escape checked |
| Use a clip | Click row, Return, or ⌘1–9; copy mode returns focus; optional one-step paste | Codec round-trip passes; automatic external paste remains a release gate |
| Pin/unpin | Keyboard, footer button, context menu or preview; pins survive retention and normal clearing | Native unpin from Pinned selects remaining item; core retention checks pass |
| Delete/recover | ⌘Delete or footer; immediate Undo; ⌘Z while Undo is visible | Native footer deletion and keyboard undo pass |
| Pause/resume | Settings and menu bar; header Resume action when paused; skipped clipboard changes are not imported afterward | Core paused/excluded behavior checked; prior release footer pause/resume verified; new header resume uses the same model action |
| Settings | Retention, session-only mode, exclusions, permission status and clearing; destructive changes confirm | Native Settings and cancellation of session-only confirmation checked |
| Missing file | Explain that original file moved/deleted; preserve current clipboard rather than restoring a dead reference | Code reviewed |
| Close/quit | Escape closes preview, clears query, then returns to previous app; quit flushes pending saves | Native Escape and graceful quit checked |
| Install/update | Drag app to Applications; guide included; quit before replacing bundle; history stored separately | DMG verified and mounted app compared to original |

## Design choices

- The bottom strip restores Navigate, Category, Paste/Copy, Pin, Delete, and Close. Action labels match actual shortcuts. Delete remains ⌘Delete to protect against deleting a clip when editing a search.
- Hover highlights a row without changing keyboard selection. This avoids unexpected scrolling and accidental selection changes.
- Preview has one main action area. The duplicate large paste control was removed.
- Empty categories never imply that the whole library is empty.
- Unavailable actions disable when no clip is selected.
- Copy mode is visible and useful before any optional Accessibility permission is granted.

## Further product work

Custom shortcut recording, launch-at-login, editable reusable snippets, sync and automatic updates are not included in this version. Add these only with their full failure and recovery paths. The current release gates are documented in RELEASE.md; a locally working preview is not evidence of clean-Mac distribution or Accessibility-enabled paste.

## Minimalist visual revision — build 2

The footer is now a single shortcut strip. The duplicate large paste button and permanent privacy/status rows are removed. Settings, preview, result count, and copy-mode status live in the header. Selection uses a subtle neutral fill without an outline; text icons have no decorative tile. The window uses native clear glass with a native under-window backdrop. Settings uses direct, descriptive labels. Whitespace-only clips have a visible label instead of an apparently empty row.

Feature priorities: named snippets, a paste queue, and on-demand image text extraction. These are proposals, not shipped features; each should do no background processing until invoked.

## Proposed next features, in order

1. **Named snippets:** give frequently reused pins a short title and an editable value. Search both. This makes addresses, replies, commands, and templates easier to recognize without ongoing background work.
2. **Paste queue:** select several clips, order them, and paste the next item with one shortcut. Show progress and an obvious cancel action. This reduces repeated palette opening when filling forms.
3. **Extract text from an image:** run local OCR only when explicitly requested in preview. Show selectable results before copying; do not silently scan the whole library. This keeps processing and battery cost tied to an intentional action.

For larger libraries, prioritize incremental history storage and thumbnail caching before adding sync or background AI. Benchmark with large images, long text, 500 recent entries and many pins; the current idle measurements do not cover those workloads.

## Recognizable links — build 5

Notion, GitHub, Figma, and Google Docs/Sheets/Slides links get destination-aware icons and labels. Readable names come from URL paths when available; opaque document IDs use honest service labels. Installed app icons are resolved once locally, with built-in fallback symbols. No page or favicon requests are made. The exact original URL remains the copy/paste payload. Preview separates the destination from the app it was copied from, exposes the full URL, and offers an explicit Open original link action. Search includes derived names and service labels.

The palette opens at 620 × 560 points and keeps its size when switching categories, searching, or opening previews. Longer lists scroll within the window; empty categories retain the same space. Manual resizing is preserved when navigating and reopening the palette.

## Design experiment — glass and motion

Branch: `design/glass-and-motion`.

- Deeper charcoal tint over native glass, with the existing fine edge highlight and a faint lavender selection fill.
- Shared category capsule moves with a 180 ms spring, including categories selected from More.
- A 140 ms opacity/5-point entrance animates the panel content without moving its window frame or deferring search focus.
- Medium-weight clip titles, quieter metadata and footer controls, and an accented Copy/Paste action.
- Preview crossfades with an 8-point horizontal offset over 160 ms. Pin symbols fill and bounce once on a state change. Keyboard selection and scrolling update immediately.
- Native folded-card illustrations settle once on appearance in onboarding and empty states. No continuous animations or new dependencies.
- Reduce Motion disables the new animations; Reduce Transparency uses an opaque charcoal surface.

Validation: debug QA bundle builds and signs; all 26 existing core checks pass. Native sample-data checks cover category selection, search filtering, preview/back, pinning, and the illustrated empty state. Exact animation timing, Reduce Motion/Transparency with live system settings, and onboarding still need human visual acceptance. The QA bundle uses sample clips without monitoring or saving clipboard history.
