import SwiftUI
import UIKit

public struct PlayerSurfaceView: UIViewControllerRepresentable {
    private let engine: PlayerEngine

    public init(engine: PlayerEngine) {
        self.engine = engine
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let controller = engine.makePlayerViewController()
        configure(controller)
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        configure(uiViewController)
        uiViewController.view.setNeedsLayout()
    }

    private func configure(_ controller: UIViewController) {
        controller.view.backgroundColor = .black
        controller.view.isOpaque = true
        controller.view.clipsToBounds = true
        controller.view.accessibilityIdentifier = "player.surface"
    }
}
