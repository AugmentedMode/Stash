import SwiftUI
import AppKit
import ApplicationServices
import StashCore

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.muted)
            .padding(.horizontal, 5).padding(.vertical, 3).background(
                .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 4)
            ).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line))
    }
}
