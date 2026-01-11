import SwiftUI
import AVKit
import SDWebImageSwiftUI

struct WhatIsLimi: View {
    @State private var navigateToHomeView = false
    @State private var isVideoInView = false

    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper?

    init() {
        if let url = Bundle.main.url(forResource: "WhatIsLimi", withExtension: "mp4") {
            let item = AVPlayerItem(url: url)
            self.player = AVQueuePlayer()
            self.looper = AVPlayerLooper(player: self.player, templateItem: item)
        } else {
            self.player = AVQueuePlayer()
            self.looper = nil
            print("Video not found")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("What is LIMI AI?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    Text("LIMI AI is your smart light management and automation assistant!")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Video that only plays when it's visible
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .global)
                        Color.clear
                            .onAppear { checkVisibility(frame) }
                            .onChange(of: frame.origin.y) { _, _ in
                                checkVisibility(frame)
                            }

                        VideoPlayer(player: player)
                            .frame(height: 180)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    .frame(height: 180)

                    Spacer().frame(height: 400) // Just to enable scrolling for test
                }
            }
            .onAppear {
                checkVisibilityManually()
            }
            .onDisappear {
                stopVideo()
            }
            .navigationBarItems(leading: Button(action: {
                navigateToHomeView = true
            }) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.charlestonGreen)
            })
            .fullScreenCover(isPresented: $navigateToHomeView) {
                HomeView()
            }
        }
    }

    // MARK: - Video Control Functions
    private func checkVisibility(_ frame: CGRect) {
        let screenHeight = UIScreen.main.bounds.height
        let isVisible = frame.minY >= 0 && frame.maxY <= screenHeight

        if isVisible && !isVideoInView {
            isVideoInView = true
            player.play()
        } else if !isVisible && isVideoInView {
            isVideoInView = false
            stopVideo()
        }
    }

    private func checkVisibilityManually() {
        isVideoInView = true
        player.play()
    }

    private func stopVideo() {
        player.pause()
        player.seek(to: .zero)
    }
}

#Preview {
    WhatIsLimi()
}
