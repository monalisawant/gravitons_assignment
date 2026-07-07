//
//  VideoModels.swift
//  GravitonesAssignment
//

import Foundation

enum VideoStatus: String, Codable {
    case processing = "PROCESSING"
    case ready = "READY"
    case failed = "FAILED"
    case unknown

    // Fall back to .unknown instead of throwing if the API adds a new status.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VideoStatus(rawValue: raw) ?? .unknown
    }
}

struct Rendition: Codable, Identifiable, Hashable {
    let resolution: String
    let bitrateKbps: Int
    let playlistUrl: String

    var id: String { resolution }

    var displayResolution: String {
        resolution.hasPrefix("R") ? String(resolution.dropFirst()).lowercased() : resolution
    }
}

struct Video: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let status: VideoStatus
    let durationSeconds: Double?
    let masterPlaylistUrl: String?
    let errorMessage: String?
    let renditions: [Rendition]
    let createdAt: String?
    let updatedAt: String?

    // Only READY videos have a usable master playlist.
    var playbackURL: URL? {
        guard status == .ready, let urlString = masterPlaylistUrl else { return nil }
        return URL(string: urlString)
    }

    var formattedDuration: String? {
        guard let seconds = durationSeconds, seconds > 0 else { return nil }
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

struct VideoPage: Decodable {
    let items: [Video]
    let total: Int
    let page: Int
    let pageSize: Int
}

// GET /api/videos/{id} wraps the video in a "video" key.
struct VideoEnvelope: Decodable {
    let video: Video
}
