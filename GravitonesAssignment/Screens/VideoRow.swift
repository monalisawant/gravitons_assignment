//
//  VideoRow.swift
//  GravitonesAssignment
//

import SwiftUI

struct VideoRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: 14) {
            VideoThumbnail(video: video)
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                StatusBadge(status: video.status)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if video.status == .ready {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

// Poster frame from the HLS stream, with a gradient placeholder while it loads.
struct VideoThumbnail: View {
    let video: Video
    var size = CGSize(width: 104, height: 68)

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: placeholderColors,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            Image(systemName: video.status == .ready ? "play.circle.fill" : "film")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 2)

            if let duration = video.formattedDuration {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                    .padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: video.id) {
            guard video.status == .ready, image == nil else { return }
            image = await ThumbnailLoader.shared.thumbnail(for: video)
        }
    }

    private var placeholderColors: [Color] {
        video.status == .ready
            ? [Color.accentColor, Color.accentColor.opacity(0.65)]
            : [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
    }
}

struct StatusBadge: View {
    let status: VideoStatus

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .processing: return "PROCESSING"
        case .ready:      return "READY"
        case .failed:     return "FAILED"
        case .unknown:    return "UNKNOWN"
        }
    }

    private var icon: String {
        switch status {
        case .processing: return "clock"
        case .ready:      return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        case .unknown:    return "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .processing: return .orange
        case .ready:      return .green
        case .failed:     return .red
        case .unknown:    return .gray
        }
    }
}
