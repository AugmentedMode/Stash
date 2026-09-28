import SwiftUI

struct PinGlyph: View {
    let pinned: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var glyph: some View {
        Image(systemName: pinned ? "pin.fill" : "pin")
            .foregroundStyle(pinned ? Color.accent : Color.quiet)
    }

    var body: some View {
        Group {
            if reduceMotion { glyph }
            else { glyph.symbolEffect(.bounce, options: .nonRepeating, value: pinned) }
        }.accessibilityHidden(true)
    }
}

/// A small native illustration; the cards settle once when the view appears.
struct ClipStackIllustration: View {
    var symbol = "text.alignleft"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            card(fill: Color(red: 0.16, green: 0.17, blue: 0.23))
                .rotationEffect(.degrees(settled ? -14 : -22))
                .offset(x: settled ? -17 : -24, y: settled ? 4 : 10)
            card(fill: Color(red: 0.23, green: 0.24, blue: 0.33))
                .rotationEffect(.degrees(settled ? 10 : 19))
                .offset(x: settled ? 14 : 22, y: settled ? -3 : 3)
            card(fill: Color(red: 0.32, green: 0.33, blue: 0.45))
                .overlay(alignment: .topTrailing) {
                    FoldCorner().fill(Color.accent.opacity(0.6))
                        .frame(width: 15, height: 15).padding(1)
                }
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.accent)
                        Capsule().fill(Color.accent.opacity(0.5)).frame(width: 36, height: 3)
                        Capsule().fill(Color.accent.opacity(0.25)).frame(width: 25, height: 3)
                    }.padding(.leading, 15)
                }
                .offset(y: settled ? 0 : -7)
        }
        .frame(width: 140, height: 104)
        .accessibilityHidden(true)
        .onAppear {
            guard !settled else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.15)) {
                settled = true
            }
        }
    }

    private func card(fill: Color) -> some View {
        FoldedCard().fill(fill)
            .overlay(FoldedCard().stroke(Color.accent.opacity(0.22), lineWidth: 0.7))
            .frame(width: 72, height: 86)
            .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
    }
}

private struct FoldCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 4), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FoldedCard: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 9
        let fold: CGFloat = 17
        var path = Path()
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: rect.width - fold, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: fold))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addQuadCurve(to: CGPoint(x: rect.width - r, y: rect.height), control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - r), control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}
