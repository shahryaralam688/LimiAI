import UIKit
import Combine

final class FloatingRootViewController: UIViewController {

    // MARK: - Subviews

    private let bubble = AIBubbleView(frame: .zero)

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private let positionKey = "floatingBubble.position"

    // MARK: - Callbacks

    var onBubbleTapped: (() -> Void)?

    // MARK: - Lifecycle

    override func loadView() {
        let passthrough = PassthroughView()
        passthrough.backgroundColor = .clear
        view = passthrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bubble.delegate = self
        view.addSubview(bubble)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if bubble.center == .zero {
            restoreOrDefaultPosition()
        }
    }

    // MARK: - Position Persistence

    private func restoreOrDefaultPosition() {
        if let saved = UserDefaults.standard.dictionary(forKey: positionKey),
           let x = saved["x"] as? CGFloat,
           let y = saved["y"] as? CGFloat {
            bubble.center = CGPoint(x: x, y: y)
        } else {
            let safeTop = view.safeAreaInsets.top + AIBubbleView.diameter / 2 + 80
            bubble.center = CGPoint(
                x: view.bounds.width - AIBubbleView.diameter / 2 - 10,
                y: safeTop
            )
        }
    }

    private func savePosition(_ point: CGPoint) {
        UserDefaults.standard.set(["x": point.x, "y": point.y], forKey: positionKey)
    }

    // MARK: - Bubble Appearance Proxy

    func setBubbleActive(_ active: Bool) {
        bubble.setActiveAppearance(active)
    }

    // MARK: - Status bar

    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - AIBubbleViewDelegate

extension FloatingRootViewController: AIBubbleViewDelegate {
    func bubbleTapped() {
        onBubbleTapped?()
    }

    func bubblePositionChanged(_ position: CGPoint) {
        savePosition(position)
    }
}

// MARK: - Passthrough View

private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
