//
//  ThumbnailLoader.swift
//  GravitonesAssignment
//

import UIKit
import AVFoundation

// The API doesn't return thumbnails, so we grab a frame from the HLS stream
// itself. Results are cached and de-duplicated so each video is generated once.
actor ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private var cache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func thumbnail(for video: Video) async -> UIImage? {
        guard let url = video.playbackURL else { return nil }
        if let cached = cache[video.id] { return cached }
        if let task = inFlight[video.id] { return await task.value }

        let task = Task { await Self.generate(from: url) }
        inFlight[video.id] = task
        let image = await task.value
        inFlight[video.id] = nil
        if let image { cache[video.id] = image }
        return image
    }

    private static func generate(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        // A second in, to skip any black leading frame.
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
