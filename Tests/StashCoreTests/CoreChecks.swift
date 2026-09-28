import AppKit

@main struct CoreChecks {
    static func main() {
        if CommandLine.arguments.contains("--benchmark") {
            SearchBenchmark.run()
            return
        }
        let probe = NSPasteboard.withUniqueName()
        let accessible =
            probe.setString("Stash test probe", forType: .string) && probe.string(forType: .string) != nil
        probe.releaseGlobally()
        guard accessible else {
            print(
                "Named pasteboards are unavailable. Run checks in a macOS login session with pasteboard access."
            )
            exit(2)
        }
        let suite = StashCoreTests()
        let tests: [(String, () throws -> Void)] = [
            ("PinnedPayloadDoesNotConsumeHistoryBudget", suite.testPinnedPayloadDoesNotConsumeHistoryBudget),
            ("HistoryBudgetKeepsNewestPrefix", suite.testHistoryBudgetKeepsNewestPrefix),
            ("CompiledSearchPreservesMatching", suite.testCompiledSearchPreservesMatching),
            ("PromptValidationUsesUTF8Budget", suite.testPromptValidationUsesUTF8Budget),
            (
                "PrivateStoreRepairsPermissionsAndReplacesData",
                suite.testPrivateStoreRepairsPermissionsAndReplacesData
            ),
            ("ScreenshotStopCancelsQueuedFailure", suite.testScreenshotStopCancelsQueuedFailure),
            ("ScreenshotObserverReleasesWhileWatching", suite.testScreenshotObserverReleasesWhileWatching),
            ("ScreenshotRoundTripAndDeduplication", suite.testScreenshotRoundTripAndDeduplication),
            ("ScreenshotFileIdentityAndPersistence", suite.testScreenshotFileIdentityAndPersistence),
            ("ScreenshotWatcherSkipsOldAndStops", suite.testScreenshotWatcherSkipsOldAndStops),
            ("IdleProbeDoesNotConsumeCopy", suite.testIdleProbeDoesNotConsumeCopy),
            ("EnergyPolicy", suite.testEnergyPolicy),
            ("HistoryWritesCoalesceAndFlush", suite.testHistoryWritesCoalesceAndFlush),
            ("HistoryWritesCommitWithoutQuit", suite.testHistoryWritesCommitWithoutQuit),
            ("HistoryWriterReportsErrors", suite.testHistoryWriterReportsErrors),
            ("MonitorOnlyReadsNewCopies", suite.testMonitorOnlyReadsNewCopies),
            ("PausedAndExcludedCopiesDoNotReappear", suite.testPausedAndExcludedCopiesDoNotReappear),
            ("RestoringClipDoesNotRecaptureIt", suite.testRestoringClipDoesNotRecaptureIt),
            ("Classification", suite.testClassification),
            ("SearchHighlightsUnicode", suite.testSearchHighlightsUnicode),
            ("RenamePreservesPayloadAndLegacyHistory", suite.testRenamePreservesPayloadAndLegacyHistory),
            ("RichTextRoundTrip", suite.testRichTextRoundTrip),
            ("SensitiveMarkersNeverCaptured", suite.testSensitiveMarkersNeverCaptured),
            ("ExcludedAppNotCaptured", suite.testExcludedAppNotCaptured),
            ("MultipleFilesRoundTrip", suite.testMultipleFilesRoundTrip),
            ("ImageAndVideoTypes", suite.testImageAndVideoTypes),
            ("UnsupportedAndOversizedDataSkipped", suite.testUnsupportedAndOversizedDataSkipped),
            ("DeduplicationPreservesPinAndIdentity", suite.testDeduplicationPreservesPinAndIdentity),
            ("RetentionAndLimitPreservePinnedItems", suite.testRetentionAndLimitPreservePinnedItems),
            ("SearchAndFilters", suite.testSearchAndFilters),
            ("LinkRecognition", suite.testLinkRecognition),
            ("AIRecognition", suite.testAIRecognition),
            ("ExpandedServiceRecognition", suite.testExpandedServiceRecognition),
            ("TextIconDetection", suite.testTextIconDetection),
            ("ReadableTicketDetails", suite.testReadableTicketDetails),
            ("SavedPrompts", suite.testSavedPrompts),
            ("LinkDomainBoundaries", suite.testLinkDomainBoundaries),
            ("LinkSearchAndOriginalPayload", suite.testLinkSearchAndOriginalPayload),
            ("DiskRoundTripAndPermissions", suite.testDiskRoundTripAndPermissions),
            ("EmptyDiskAndEmptyClipboard", suite.testEmptyDiskAndEmptyClipboard),
        ]
        for (name, run) in tests {
            let before = failures

            do { try run() } catch {
                failures += 1
                print("FAIL: \(name) threw an error")
            }

            if before == failures { print("PASS: \(name)") }
        }
        print("\(tests.count) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
