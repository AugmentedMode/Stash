import SwiftUI
import AppKit
import ApplicationServices
import StashCore

struct DetailView: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    let imageNamespace: Namespace.ID
    var body: some View {
        if clip.isVisual {
            ImageDetailView(model: model, clip: clip, imageNamespace: imageNamespace)
        } else {
            standardDetail
        }
    }
    private var standardDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(clip.kind.title.uppercased(), systemImage: clip.kind.symbol).font(
                    .system(size: 10, weight: .medium)
                ).tracking(1.1).foregroundStyle(Color.muted)
                Spacer()

                Button {
                    model.togglePin(clip)
                } label: {
                    PinGlyph(pinned: clip.pinned)
                }.buttonStyle(.plain).help(clip.pinned ? "Unpin (⌘P)" : "Pin (⌘P)").accessibilityLabel(
                    clip.pinned ? "Unpin clip" : "Pin clip")
                Button {
                    model.openActions(for: clip)
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Color.muted)
                }
                .buttonStyle(.plain).help("Actions · ⌘K").accessibilityLabel("Clip actions")
            }.padding(.bottom, 23)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let link = clip.linkPresentation {
                        HStack(spacing: 12) {
                            LinkIcon(service: link.service).frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(link.title).font(.system(size: 19, weight: .medium))
                                Text(link.label + " · " + link.host).font(.system(size: 12)).foregroundStyle(
                                    Color.muted)
                            }
                        }
                        Text("Original link").font(.system(size: 11, weight: .medium)).foregroundStyle(
                            Color.muted)
                        Text(clip.text).font(.system(size: 13)).textSelection(.enabled).foregroundStyle(
                            Color.white.opacity(0.88)
                        ).fixedSize(horizontal: false, vertical: true)
                        if link.titleFromPath {
                            Text("Display name derived from the URL.").font(.system(size: 11))
                                .foregroundStyle(Color.muted)
                        }
                        if let url = URL(string: clip.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            Button("Open original link", systemImage: "arrow.up.right") {
                                NSWorkspace.shared.open(url)
                            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.accent)
                        }
                    } else if clip.kind == .color {
                        RoundedRectangle(cornerRadius: 14).fill(Color.hex(clip.text)).frame(height: 165)
                            .overlay(alignment: .bottomLeading) {
                                Text(clip.text.uppercased()).font(
                                    .system(size: 22, weight: .medium, design: .monospaced)
                                ).foregroundStyle(.black.opacity(0.65)).padding(18)
                            }
                        Text("A color worth keeping.").font(.system(size: 18, weight: .medium)).tracking(-0.3)
                    } else if clip.kind == .file || clip.kind == .video {
                        ForEach(clip.fileURLs, id: \.absoluteString) { url in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(
                                    width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(url.lastPathComponent).font(.system(size: 14, weight: .medium))

                                    Text(url.deletingLastPathComponent().path).font(.system(size: 11))
                                        .foregroundStyle(Color.muted).lineLimit(2)
                                }
                            }
                        }
                    } else {
                        Text(clip.text).font(
                            .system(
                                size: clip.kind == .text ? 17 : 16, weight: .regular,
                                design: clip.text.contains("let ") ? .monospaced : .default)
                        ).lineSpacing(7).foregroundStyle(Color.white.opacity(0.9)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 20)
            VStack(spacing: 10) {
                HStack {
                    Text("Copied from").foregroundStyle(Color.muted)
                    Spacer()
                    SourceAppIcon(clip: clip)
                    Text(clip.sourceName).foregroundStyle(Color.muted)
                }.font(.system(size: 11))
                meta("Added", clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                meta(
                    "Content",
                    clip.kind == .image || clip.kind == .screenshot || clip.kind == .file
                        || clip.kind == .video
                        ? ByteCountFormatter.string(fromByteCount: Int64(clip.byteCount), countStyle: .file)
                        : "\(clip.text.count) characters")
            }.padding(.vertical, 18).overlay(alignment: .top) {
                Rectangle().fill(Color.line).frame(height: 1)
            }

        }.padding(23).background(Color.white.opacity(0.008))
    }
    func meta(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.muted)
            Spacer()

            Text(value).foregroundStyle(Color.white.opacity(0.72)).lineLimit(1)
        }.font(.system(size: 11))
    }
}
