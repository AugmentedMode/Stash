# Efficiency investigation — September 27, 2026

## Observed problem

The existing running build (PID 60128, launched at 12:03) consumed 86.1% and 98.5% CPU in two five-second samples around 13:11. Its physical footprint was approximately 695–706 MB. A three-second `sample` trace put the main thread in repeated SwiftUI lazy-stack placement and transaction processing. The app subsequently timed out when asked to return its accessibility state. It was stopped after normal UI quit could not be completed.

## Changes

- Each lazy-list item has one stable child containing its optional heading and row.
- `NSHostingView.sizingOptions = []`: the panel owns window size, avoiding intrinsic-size feedback through the glass container.
- Filtered/sorted results are cached and invalidated only by history, query or filter changes.
- Idle clipboard checks read only `changeCount`; app metadata and exclusion sets are resolved only for a changed clipboard.
- Capture timers are invalidated while paused, during display/system sleep and in inactive user sessions. Resumption skips intervening clipboard contents.
- Low Power Mode uses a 1.2-second timer instead of 0.6 seconds. Both allow 25% timer tolerance. That halves scheduled checks, not necessarily battery consumption. Copies replaced between checks can be missed; the app does not promise an event stream of every copy.
- History writes retain the newest pending snapshot and coalesce within a fixed one-second window. Encoding/writes run on a utility queue. Quit and system sleep flush pending writes. Abrupt crashes may lose the latest second of changes.
- Session-only capture does not repeatedly save an empty file.
- Retention scans occur every five minutes, and an unchanged history is not republished to SwiftUI.

## Measurements after the layout/energy fix

With the same saved library, the rebuilt process (PID 74821) reported 0.0% CPU in all four `top` samples, five seconds apart, around 13:14. Memory was approximately 46 MB; CPU time stayed at 0.40 seconds throughout that sample window.

This is evidence that the observed runaway loop stopped, not a battery-life estimate. The old process had run for over an hour while the new one was freshly launched, so the memory figures are not a controlled long-duration comparison. No watt-hour measurement or full discharge test was performed. The later visual revision is measured separately below.

## Regression checks

20 core checks pass. New checks cover a non-consuming clipboard change probe, polling policy for normal/low-power/paused/suspended states, 100 queued snapshots coalescing to one latest write, session-only clearing superseding a pending save, automatic timed saving, quit-style flush, and write-error reporting. Existing capture, exclusions, rich content, retention, search, and persistence checks still pass.

The actual OS Low Power Mode and display sleep settings were not changed during testing. Those lifecycle branches are code-reviewed; policy behavior is tested. Clipboard content and user history are not copied into diagnostic reports.

Apple recommends minimizing timers, giving necessary timers tolerance, and adapting to Low Power Mode: [timer energy guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html), [power notifications](https://developer.apple.com/documentation/xcode/responding-to-power-notifications).

## Remaining efficiency work

For very large image-heavy libraries, the JSON store still rewrites the entire retained history when a save occurs. Incremental storage with separate image blobs would reduce write amplification further. Decoded image/thumbnail caching is another candidate to profile with image-heavy histories. These are future improvements, not changes in this build.

## Final redesigned build

The redesigned release (PID 76307) was sampled seven times, five seconds apart, for 30 seconds. Six samples reported 0.0% CPU and one reported 0.2%; memory was 42–43 MB. Total CPU time moved from 0.30 to 0.32 seconds. This is still a short local measurement, not a long-duration battery benchmark. The only subsequent app-source change was shortening the whitespace-only clip label.

Native Settings displayed the energy behavior. Pausing and closing Settings exposed the compact header Resume control; resuming restored Copy mode. Capture was resumed before graceful quit. OS sleep and Low Power Mode were not toggled during the session.
