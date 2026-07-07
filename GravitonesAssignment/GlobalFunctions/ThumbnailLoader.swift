//
//  ThumbnailLoader.swift
//  GravitonesAssignment
//

import UIKit
import AVFoundation

// The API doesn't return thumbnails, so we grab a frame from the HLS stream
// itself. Results are cached and de-duplicated, and generation is capped at a
// couple at a time so we don't overload the media stack (which competes with
// playback and, on the Simulator, causes decode failures).
actor ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let maxConcurrent = 2
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private var cache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func thumbnail(for video: Video) async -> UIImage? {
        guard let url = video.playbackURL else { return nil }
        if let cached = cache[video.id] { return cached }
        if let task = inFlight[video.id] { return await task.value }

        let task = Task { await self.generateGated(from: url) }
        inFlight[video.id] = task
        let image = await task.value
        inFlight[video.id] = nil
        if let image { cache[video.id] = image }
        return image
    }

    private func generateGated(from url: URL) async -> UIImage? {
        await acquire()
        defer { release() }
        return await Self.generate(from: url)
    }

    // MARK: - Concurrency gate

    private func acquire() async {
        if active < maxConcurrent {
            active += 1
        } else {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    private func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()          // hand our slot straight to the next waiter
        } else {
            active -= 1
        }
    }

    private static func generate(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        // Accept a nearby keyframe — exact-frame seeking on HLS often fails.
        generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
