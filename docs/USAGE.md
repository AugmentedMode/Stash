# Using Stash

Stash lives in the menu bar. Press **⌘⇧V** to open it while working in another app.
Type to search, use **↑/↓** to select a result, and press **Return** to paste.
Without Accessibility permission, Stash copies and returns to your previous app;
finish with **⌘V**. Closing the palette keeps collection running. Right-click the
menu-bar icon to pause or quit.

## Browsing and actions

Use the category bar to choose All, Pinned, Text, Links, Screenshots, or Prompts.
Images, Files, Emails, Colors, and Videos are under More. **←/→** switches categories
when search is empty; **⌥←/⌥→** works during search. **⌘F** focuses search.

Click a history row to paste it, or open its context menu to copy without returning
to another app. **⌘K** opens searchable actions for the selected clip:

- Paste, copy, or paste text without formatting (**⇧Return**).
- Preview (**⌘Y**), pin/unpin (**⌘P**), or rename the label inside Stash.
- Open the original link or reveal the original file in Finder.
- Save a text clip as a reusable prompt.
- Delete (**⌘Delete**). Use **⌘Z** while Undo is visible to restore a deletion.

Renaming changes the display label, never the original clipboard payload. Link
names come from URL paths; opaque IDs retain honest service labels. No pages or
favicons are fetched. Previews stay inside the palette, which preserves manual
window resizing when switching categories and reopening.

For images and screenshots, switch to the thumbnail grid. Click to select;
double-click or press Space to expand. Expanded images begin fitted to the window.
Click or choose Zoom in to enlarge, scroll to explore, and choose Fit to reset.

Escape closes the preview first, then clears search, then dismisses the palette.
Settings opens inline with **⌘,**; Back or Escape returns to the previous view.

## Collect saved screenshots

Open **Screenshots → Set up screenshots**, then enable **Collect saved screenshots**.
Choose the same save folder as macOS Screenshot (**⇧⌘5 → Options**). Stash initially
uses the configured macOS location, or Desktop when no location is configured.

**Copy new screenshots to clipboard** is on by default within this opt-in feature.
Take a screenshot, wait for macOS to save it, then paste with **⌘V**. Turn that
second switch off to collect screenshots without changing your clipboard. Newer
clipboard activity takes priority over an image still being processed.

Only new files carrying macOS screenshot metadata are imported. Existing files
and captures made while paused or suspended are skipped. Filenames and system
language do not determine screenshot identity. PNG, JPEG, and TIFF captures are
normalized to PNG and stored, so deleting the original screenshot does not break
pasting. Limits are 20 MB before/after conversion, 16,000 pixels per dimension,
and 40 megapixels.

Folder access errors appear in screenshot settings. Choose the folder again to
restore access. Application exclusions apply to clipboard reads, not saved
screenshot files. Normal retention and session-only settings still apply.

## Saved prompts

Open **Prompts** or press **⌘⇧P**. Use **⌘N** to create a named prompt and **⌘S** to
save. Drafts survive category changes. Search matches the name and contents.

Fields such as `{{topic}}` and `{{tone}}` become inputs when a prompt is opened.
Repeated fields share one value. Fill every field, then use **⌘⇧C** to copy or
**⌘Return** to paste/return. **Tab** moves between fields; **Esc** returns to the
list. Use **⌘E** to edit a selected prompt.

This is a local template library. It does not call an AI service. Explicitly saved
prompts are separate from clipboard history and survive expiry, clearing history,
and session-only capture.

## If the shortcut does not work

The real Stash app must be running; the global shortcut cannot launch a closed
app. The QA preview deliberately has no global shortcut. If another app or Stash
copy claims **⌘⇧V**, open Stash from the menu bar and look for its shortcut warning.

Automatic paste checks that the destination app is active before sending a paste
keystroke. If it cannot activate the destination, the content remains copied and
the palette explains how to paste manually.
