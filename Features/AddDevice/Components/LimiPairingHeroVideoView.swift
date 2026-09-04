//
//  LimiPairingHeroVideoView.swift
//  Limi
//
//  Looping hub hero for Add Device pairing / Wi-Fi setup.
//  Replaces the RealityKit USDZ preview. Silent, seamless, never freezes
//  while the card is on screen.
//

import AVFoundation
import SwiftUI

enum LimiPairingHeroVideo {
    static let resourceName = "LimiHubHeroLoop"
}

struct LimiPairingHeroVideoView: View {
    var cornerRadius: CGFloat = 22

    var body: some View {
        LoopingHeroPlayerRepresentable()
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: max(cornerRadius - 6, 12), style: .continuous))
            .padding(8)
            .neuElevation(level: -1, cornerRadius: cornerRadius)
            .accessibilityHidden(true)
    }
}

private struct LoopingHeroPlayerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> LoopingHeroPlayerView {
        let view = LoopingHeroPlayerView()
        view.start()
        return view
    }

    func updateUIView(_ uiView: LoopingHeroPlayerView, context: Context) {
        uiView.ensurePlaying()
    }

    static func dismantleUIView(_ uiView: LoopingHeroPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingHeroPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var becameActiveObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func start() {
        guard queuePlayer == nil else {
            ensurePlaying()
            return
        }
        guard let url = Bundle.main.url(
            forResource: LimiPairingHeroVideo.resourceName,
            withExtension: "mp4"
        ) else {
            DeviceConsole.log(.config, "pairing hero video missing \(LimiPairingHeroVideo.resourceName).mp4")
            return
        }

        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(items: [])
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player
        playerLayer.player = player
        player.play()

        becameActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.ensurePlaying()
        }
    }

    func ensurePlaying() {
        guard let player = queuePlayer else { return }
        if player.timeControlStatus != .playing {
            player.play()
        }
    }

    func stop() {
        if let becameActiveObserver {
            NotificationCenter.default.removeObserver(becameActiveObserver)
            self.becameActiveObserver = nil
        }
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        playerLayer.player = nil
        queuePlayer = nil
    }
}
