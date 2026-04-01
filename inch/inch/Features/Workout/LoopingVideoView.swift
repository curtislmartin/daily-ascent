import SwiftUI
import AVFoundation

/// Displays a muted, looping MP4 clip. Falls back to a static image if the
/// video cannot be loaded. This is the only UIViewRepresentable in the app —
/// AVPlayerLayer has no native SwiftUI equivalent for looping muted video.
struct LoopingVideoView: UIViewRepresentable {
    let exerciseId: String
    let fallbackImageName: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Configure audio session so the clip doesn't interrupt music playback
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        guard !UIAccessibility.isReduceMotionEnabled,
              let url = Bundle.main.url(forResource: exerciseId, withExtension: "mp4") else {
            // Fallback: show static image
            addFallbackImage(to: view)
            return view
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer

        // Loop on end
        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Keep playerLayer frame in sync with view bounds
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fallbackImageName: fallbackImageName)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.player?.pause()
        if let observer = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func addFallbackImage(to view: UIView) {
        let imageView = UIImageView(image: UIImage(named: fallbackImageName))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    final class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var loopObserver: Any?
        let fallbackImageName: String

        init(fallbackImageName: String) {
            self.fallbackImageName = fallbackImageName
        }
    }
}
