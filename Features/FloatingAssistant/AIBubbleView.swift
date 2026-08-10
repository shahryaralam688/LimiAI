import UIKit
import Combine
import SwiftUI

protocol AIBubbleViewDelegate: AnyObject {
    func bubbleTapped()
    func bubblePositionChanged(_ position: CGPoint)
}

final class AIBubbleView: UIButton {

    weak var delegate: AIBubbleViewDelegate?

    // MARK: - Constants

    static let diameter: CGFloat = 56

    // MARK: - State

    private var panStartCenter: CGPoint = .zero
    private var isDragging = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var isActive = false

    // MARK: - Subviews

    private let orbState: LimiOrbSceneState
    private let orbHost: UIHostingController<LimiOrbSceneController>
    private let pulseLayer = CAShapeLayer()
    private var isAnimatingPulse = false
    private let borderLayer = CAShapeLayer()

    // MARK: - Colors

    private let accentColor = UIColor.appBrandPrimary
    private let mutedColor = UIColor.appBorderPrimary

    // MARK: - Init

    override init(frame: CGRect) {
        orbState = LimiOrbSceneState(isActive: false, size: Self.diameter)
        orbHost = UIHostingController(rootView: LimiOrbSceneController(state: orbState))
        super.init(frame: frame)
        setupAppearance()
        setupGestures()
        setupPulseLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Appearance

    private func setupAppearance() {
        let size = Self.diameter
        bounds = CGRect(x: 0, y: 0, width: size, height: size)
        layer.cornerRadius = size / 2
        clipsToBounds = false

        orbHost.view.backgroundColor = .clear
        orbHost.view.frame = bounds
        orbHost.view.layer.cornerRadius = size / 2
        orbHost.view.clipsToBounds = true
        orbHost.view.isUserInteractionEnabled = false
        addSubview(orbHost.view)

        setImage(nil, for: .normal)

        // Edge stroke
        borderLayer.path = UIBezierPath(ovalIn: bounds).cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = mutedColor.withAlphaComponent(0.3).cgColor
        borderLayer.lineWidth = 0.8
        layer.addSublayer(borderLayer)

        // Shadow (muted for off state)
        layer.shadowColor = mutedColor.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.4
    }

    private func setupPulseLayer() {
        let size = Self.diameter
        let pulseBounds = CGRect(x: -8, y: -8, width: size + 16, height: size + 16)
        pulseLayer.path = UIBezierPath(ovalIn: pulseBounds).cgPath
        pulseLayer.fillColor = accentColor.withAlphaComponent(0.2).cgColor
        pulseLayer.opacity = 0
        layer.insertSublayer(pulseLayer, at: 0)
    }

    // MARK: - Pulse Animation

    private func startPulse() {
        guard !isAnimatingPulse else { return }
        isAnimatingPulse = true

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.4
        opacityAnim.toValue = 0.0

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.9
        scaleAnim.toValue = 1.4

        let group = CAAnimationGroup()
        group.animations = [opacityAnim, scaleAnim]
        group.duration = 1.2
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        pulseLayer.add(group, forKey: "pulse")
    }

    private func stopPulse() {
        isAnimatingPulse = false
        pulseLayer.removeAnimation(forKey: "pulse")
        pulseLayer.opacity = 0
    }

    // MARK: - Gestures (tap + drag only, no long-press)

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    @objc private func handleTap() {
        feedbackGenerator.impactOccurred()
        animateTapBounce()
        delegate?.bubbleTapped()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            isDragging = true
            panStartCenter = center
            UIView.animate(withDuration: 0.15) { self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) }

        case .changed:
            center = CGPoint(
                x: panStartCenter.x + translation.x,
                y: panStartCenter.y + translation.y
            )

        case .ended, .cancelled:
            isDragging = false
            UIView.animate(withDuration: 0.15) { self.transform = .identity }
            snapToEdge(in: superview, velocity: gesture.velocity(in: superview))

        default:
            break
        }
    }

    // MARK: - Edge Snapping

    private func snapToEdge(in container: UIView, velocity: CGPoint) {
        let safeInsets = container.safeAreaInsets
        let halfWidth = Self.diameter / 2
        let margin: CGFloat = 6

        let leftX = safeInsets.left + halfWidth + margin
        let rightX = container.bounds.width - safeInsets.right - halfWidth - margin

        let targetX: CGFloat
        if abs(velocity.x) > 200 {
            targetX = velocity.x > 0 ? rightX : leftX
        } else {
            targetX = center.x < container.bounds.midX ? leftX : rightX
        }

        let minY = safeInsets.top + halfWidth + margin
        let maxY = container.bounds.height - safeInsets.bottom - halfWidth - margin
        let targetY = min(max(center.y, minY), maxY)

        let targetPoint = CGPoint(x: targetX, y: targetY)

        let animator = UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.7) {
            self.center = targetPoint
        }
        animator.addCompletion { _ in
            self.delegate?.bubblePositionChanged(targetPoint)
        }
        animator.startAnimation()
    }

    // MARK: - Tap Feedback

    private func animateTapBounce() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 4) {
                self.transform = .identity
            }
        }
    }

    // MARK: - Active State (on/off toggle)

    func setActiveAppearance(_ active: Bool) {
        isActive = active
        orbState.isActive = active

        if active {
            startPulse()
            borderLayer.strokeColor = accentColor.withAlphaComponent(0.35).cgColor
            layer.shadowColor = accentColor.withAlphaComponent(0.5).cgColor
            layer.shadowRadius = 20
            layer.shadowOpacity = 0.9
        } else {
            stopPulse()
            borderLayer.strokeColor = mutedColor.withAlphaComponent(0.3).cgColor
            layer.shadowColor = mutedColor.cgColor
            layer.shadowRadius = 8
            layer.shadowOpacity = 0.4
        }
    }
}
