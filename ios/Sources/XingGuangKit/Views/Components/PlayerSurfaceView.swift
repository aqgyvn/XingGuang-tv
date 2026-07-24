import SwiftUI
import UIKit

public struct PlayerSurfaceView: UIViewControllerRepresentable {
    private let engine: PlayerEngine

    public init(engine: PlayerEngine) {
        self.engine = engine
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        engine.makePlayerViewController()
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
