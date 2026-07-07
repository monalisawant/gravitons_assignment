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
            .background(backgroundGradient.ignoresSafeArea())
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

    // MARK: - Playable

    private func playable(url: URL) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Keep the player out of the ScrollView and unclipped, otherwise
                // AVKit's full-screen transition renders black.
                playerBox(in: geo.size)
                ScrollView {
                    metadataCard.padding(16)
                }
            }
        }
        .onAppear { viewModel.load(url: url) }
        .onDisappear { viewModel.tearDown() }
    }

    // Sizes to the real video ratio, capping portrait height. AVKit letterboxes
    // inside the black box, so 16:9 is a fine fallback until the size is known.
    private func playerBox(in available: CGSize) -> some View {
        let ratio = viewModel.aspectRatio ?? (16.0 / 9.0)
        let height = min(available.width / ratio, available.height * 0.6)

        return ZStack {
            Color.black
            VideoPlayerView(player: viewModel.player)
            playbackOverlay
        }
        .frame(width: available.width, height: height)
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
            .transition(.opacity)
        case .failed(let message):
            ZStack {
                Color.black.opacity(0.55)
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
            .transition(.opacity)
        default:
            EmptyView()
        }
    }

    // MARK: - Metadata

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(video.title)
                .font(.title2.weight(.bold))

            if let duration = video.formattedDuration {
                InfoChip(icon: "clock", text: duration)
            }

            if !video.description.isEmpty {
                Text(video.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Small components

struct InfoChip: View {
    let icon: String
    let text: String
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(.tertiarySystemBackground), in: Capsule())
            .foregroundStyle(.secondary)
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
