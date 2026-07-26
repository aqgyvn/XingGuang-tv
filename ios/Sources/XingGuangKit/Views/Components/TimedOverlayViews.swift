import SwiftUI

struct TimedSubtitleOverlayView: View {
    let cues: [TimedTextCue]
    let position: TimeInterval
    let fontSize: Double
    let bottomOffset: Double

    private var text: String {
        cues.filter { position >= $0.start && position < $0.end }
            .map(\.text)
            .joined(separator: "\n")
    }

    var body: some View {
        VStack {
            Spacer()
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: min(max(fontSize, 14), 42), weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 14)
                    .padding(.bottom, min(max(bottomOffset, 8), 120))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DanmakuOverlayView: View {
    let cues: [DanmakuCue]
    let position: TimeInterval

    private var activeCues: [DanmakuCue] {
        Array(cues.lazy.filter { position >= $0.start && position < $0.start + $0.duration }.prefix(36))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(activeCues) { cue in
                    Text(cue.text)
                        .font(.system(size: min(max(cue.fontSize, 14), 32), weight: .semibold))
                        .foregroundColor(Color(rgb: cue.color))
                        .lineLimit(1)
                        .shadow(color: .black, radius: 1, x: 1, y: 1)
                        .position(position(for: cue, in: geometry.size))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func position(for cue: DanmakuCue, in size: CGSize) -> CGPoint {
        let laneHeight = max(min(size.height / 7, 34), 22)
        switch cue.placement {
        case .scrolling:
            let progress = min(max((position - cue.start) / max(cue.duration, 0.1), 0), 1)
            let x = CGFloat(Double(size.width) + 100 - progress * (Double(size.width) + 200))
            let lane = cue.id % 6
            return CGPoint(x: x, y: laneHeight * CGFloat(Double(lane) + 0.75))
        case .top:
            return CGPoint(x: size.width / 2, y: laneHeight * CGFloat(Double(cue.id % 3) + 0.75))
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - laneHeight * CGFloat(Double(cue.id % 3) + 1.25))
        }
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
