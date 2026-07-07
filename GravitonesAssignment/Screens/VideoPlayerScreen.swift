//
//  VideoPlayerScreen.swift
//  GravitonesAssignment
//

import SwiftUI

struct VideoPlayerScreen: View {
    let video: Video
    @StateObject private var viewModel = VideoPlayerViewModel()

    var body: some View {
        content
            .navigationTitle(video.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch video.status {
        case .ready:
            if let url = video.playbackURL {
                playable(url: url)
            } else {
                StatusMessageView(icon: "exclamationmark.triangle.fill", tint: .orange,
                                  title: "Unavailable",
                                  message: "This video is marked ready but has no playable URL.")
            }
        case .processing:
            StatusMessageView(icon: "clock.arrow.circlepath", tint: .orange,
                              title: "Still Processing",
                              message: "This video is still being transcoded. Please check back soon.",
                              showsSpinner: true)
        case .failed:
            StatusMessageView(icon: "xmark.octagon.fill", tint: .red,
                              title: "Transcoding Failed",
                              message: video.errorMessage ?? "This video failed to process and can't be played.")
        case .unknown:
            StatusMessageView(icon: "questionmark.circle.fill", tint: .gray,
                              title: "Unavailable",
                              message: "This video is in an unknown state.")
        }
    }

    private func playable(url: URL) -> some View {
        let ratio = viewModel.aspectRatio ?? (16.0 / 9.0)
        return ZStack {
            Color.black.ignoresSafeArea()
            video(ratio: ratio)
        }
        // Cleanup happens in the view model's deinit (screen popped), not here —
        // AVKit fires onDisappear during the full-screen transition.
        .onAppear { viewModel.load(url: url, title: video.title) }
    }

    // Portrait fills the screen; 16:9 sits centered in the middle.
    @ViewBuilder
    private func video(ratio: CGFloat) -> some View {
        let stack = ZStack {
            VideoPlayerView(viewModel: viewModel)
            playbackOverlay
        }
        if ratio < 1 {
            stack.ignoresSafeArea()
        } else {
            stack.aspectRatio(ratio, contentMode: .fit)
        }
    }

    @ViewBuilder
    private var playbackOverlay: some View {
        switch viewModel.state {
        case .buffering:
            ZStack {
                Color.black.opacity(0.25)
                VStack(spacing: 10) {
                    ProgressView().tint(.white).scaleEffect(1.4)
                    Text("Buffering…").font(.caption).foregroundStyle(.white.opacity(0.9))
                }
            }
        case .failed(let message):
            ZStack {
                Color.black.opacity(0.6)
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundStyle(.yellow)
                    Text("Playback Error").font(.headline).foregroundStyle(.white)
                    Text(message)
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button {
                        viewModel.retry()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }
                .padding()
            }
        default:
            EmptyView()
        }
    }
}

// Centered message for the non-playable video states.
struct StatusMessageView: View {
    let icon: String
    var tint: Color = .secondary
    let title: String
    let message: String
    var showsSpinner: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(tint)
            }
            if showsSpinner {
                ProgressView().padding(.top, 4)
            }
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
