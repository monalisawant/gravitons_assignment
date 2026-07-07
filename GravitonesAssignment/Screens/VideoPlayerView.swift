//
//  VideoPlayerView.swift
//  GravitonesAssignment
//

import SwiftUI
import AVKit

// AVKit already does adaptive bitrate switching across the HLS renditions.
struct VideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: VideoPlayerViewModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = viewModel.player
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== viewModel.player {
            controller.player = viewModel.player
        }

        // Start playback once the item is ready. Portrait videos auto-enter
        // full screen; landscape ones play inline (full screen on demand, in
        // landscape). Guarded by the token so it runs once per loaded item.
        if viewModel.readyToBeginPlayback, context.coordinator.startedToken != viewModel.playbackToken {
            context.coordinator.startedToken = viewModel.playbackToken
            controller.entersFullScreenWhenPlaybackBegins = viewModel.isPortrait
            viewModel.player.play()
        }
    }

    final class Coordinator {
        var startedToken = -1
    }
}
