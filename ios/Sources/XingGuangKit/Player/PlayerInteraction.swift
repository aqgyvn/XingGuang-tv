import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

public enum PlayerAspectMode: Int, CaseIterable, Hashable, Identifiable {
    case original = 0
    case wide = 1
    case standard = 2
    case fill = 3
    case crop = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .original: return "原始"
        case .wide: return "16:9"
        case .standard: return "4:3"
        case .fill: return "填充"
        case .crop: return "裁剪"
        }
    }

    fileprivate var viewportRatio: CGFloat {
        self == .standard ? 4.0 / 3.0 : 16.0 / 9.0
    }

    fileprivate var scale: CGSize {
        switch self {
        case .fill: return CGSize(width: 1.18, height: 1)
        case .crop: return CGSize(width: 1.18, height: 1.18)
        default: return CGSize(width: 1, height: 1)
        }
    }
}

public extension View {
    func playerAspect(_ mode: PlayerAspectMode) -> some View {
        modifier(PlayerAspectModifier(mode: mode))
    }
}

private struct PlayerAspectModifier: ViewModifier {
    let mode: PlayerAspectMode

    func body(content: Content) -> some View {
        content
            .aspectRatio(mode.viewportRatio, contentMode: .fit)
            .scaleEffect(x: mode.scale.width, y: mode.scale.height)
            .clipped()
    }
}

public struct PlayerGestureOverlay: View {
    private let aspectMode: PlayerAspectMode
    @State private var gestureKind: GestureKind = .none
    @State private var initialValue: Float = 0
    @State private var displayedValue: Float?

    public init(aspectMode: PlayerAspectMode) {
        self.aspectMode = aspectMode
    }

    public var body: some View {
        ZStack {
            SystemVolumeView()
                .frame(width: 1, height: 1)
                .opacity(0.001)

            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dragGesture(size: proxy.size))

                if let displayedValue, gestureKind != .ignored {
                    VStack(spacing: 8) {
                        Image(systemName: gestureKind == .brightness ? "sun.max.fill" : "speaker.wave.2.fill")
                        Text("\(Int((displayedValue * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(aspectMode.viewportRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard size.height > 0 else { return }
                if gestureKind == .none {
                    guard abs(value.translation.height) > abs(value.translation.width) else {
                        gestureKind = .ignored
                        return
                    }
                    gestureKind = value.startLocation.x < size.width / 2 ? .brightness : .volume
                    initialValue = gestureKind == .brightness
                        ? Float(UIScreen.main.brightness)
                        : SystemVolumeController.shared.currentValue
                }
                guard gestureKind != .ignored else { return }
                let delta = Float(-value.translation.height / size.height * 1.5)
                let value = min(max(initialValue + delta, 0), 1)
                displayedValue = value
                if gestureKind == .brightness {
                    UIScreen.main.brightness = CGFloat(value)
                } else {
                    SystemVolumeController.shared.set(value)
                }
            }
            .onEnded { _ in
                gestureKind = .none
                displayedValue = nil
            }
    }
}

private enum GestureKind {
    case none
    case ignored
    case brightness
    case volume
}

private final class SystemVolumeController {
    static let shared = SystemVolumeController()
    weak var slider: UISlider?

    var currentValue: Float {
        slider?.value ?? AVAudioSession.sharedInstance().outputVolume
    }

    func set(_ value: Float) {
        slider?.setValue(value, animated: false)
        slider?.sendActions(for: .valueChanged)
    }
}

private struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        SystemVolumeController.shared.slider = view.subviews.compactMap { $0 as? UISlider }.first
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        SystemVolumeController.shared.slider = uiView.subviews.compactMap { $0 as? UISlider }.first
    }
}
