import Foundation
import StashCore

/// Opt-in synthetic microbenchmark; does not touch clipboard, preferences, or disk.
enum SearchBenchmark {
    static func run() {
        let now = Date()
        let clips = (0..<500).map { index in
            Clip(
                createdAt: now.addingTimeInterval(-Double(index)), sourceName: "Notes",
                kind: .text,
                text: "Project \(index) café design review " + String(repeating: "meeting notes ", count: 20),
                pinned: index.isMultiple(of: 20))
        }
        let history = History(clips: clips)
        let query = "cafe design review"
        let iterations = 100
        var checksum = 0
        func measure(_ work: () -> [Clip]) -> Double {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations { checksum += work().count }
            return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        }
        let perItem = measure {
            clips.filter { $0.matches(query) }.sorted {
                if $0.pinned != $1.pinned { return $0.pinned }
                return $0.createdAt > $1.createdAt
            }
        }
        let sharedQuery = measure { history.filtered(query: query) }
        print("Synthetic search: 500 text clips × \(iterations) searches")
        print(
            String(
                format: "Tokenize per clip: %.1f ms; tokenize once per search: %.1f ms", perItem, sharedQuery)
        )
        print("Result checksum: \(checksum). This does not measure UI latency or energy use.")
    }
}
