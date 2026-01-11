
import UIKit
import AVKit
import SwiftUI
extension UIColor {
    static let charlestonGreens = UIColor(red: 23/255, green: 29/255, blue: 30/255, alpha: 1.0)
}
class AnimationVideoView: UIViewController {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false

    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .charlestonGreens  // ✅ Set background to black
        
        playBackgroundVideo()

        // Pause video when app goes to background
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo), name: UIApplication.willResignActiveNotification, object: nil)
        
        // Resume video when app returns
        NotificationCenter.default.addObserver(self, selector: #selector(resumeVideo), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func playBackgroundVideo() {
        guard let path = Bundle.main.path(forResource: "logoanimationupdate - Trim", ofType: "mp4") else {
            print("Video file not found")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resize // ✅ Shows video in original size
        
        view.layer.insertSublayer(playerLayer!, at: 0)
        
        NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        player?.play()
    }


    @objc func pauseVideo() {
        player?.pause()
    }

    @objc func resumeVideo() {
        player?.play()
    }
    
    @objc func videoDidFinishPlaying() {
//        hasLaunchedBefore = true

        navigateToNextScreen()
    }
    
    func navigateToNextScreen() {
        let nextVC = UIHostingController(rootView: OnboardingView()) // Use SwiftUI View
        nextVC.modalPresentationStyle = .fullScreen
        self.present(nextVC, animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}



import SwiftUI  // ✅ Import SwiftUI

struct AnimationVideoViewPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AnimationVideoView {
        return AnimationVideoView()
    }

    func updateUIViewController(_ uiViewController: AnimationVideoView, context: Context) {}
}

struct AnimationVideoView_Previews: PreviewProvider {
    static var previews: some View {
        AnimationVideoViewPreview()
            .edgesIgnoringSafeArea(.all)
    }
}
