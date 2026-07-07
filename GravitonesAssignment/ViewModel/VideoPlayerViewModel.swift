//
//  VideoPlayerViewModel.swift
//  GravitonesAssignment
//

import Foundation
import AVFoundation

enum PlaybackState: Equatable {
    case idle
    case buffering
    case playing
    case paused
    case ended
    case failed(String)
}

@MainActor
final class VideoPlayerViewModel: ObservableObject {

    @Published private(set) var state: PlaybackState = .idle

    // Real video aspect ratio (width / height), known once the first variant
    // loads. nil until then. Portrait videos are < 1.
    @Published private(set) var aspectRatio: CGFloat?

    let player = AVPlayer()

    private var currentURL: URL?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var presentationSizeObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []

    // Safe to call repeatedly (e.g. on redraw) — only reloads if the URL changed.
    func load(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        start(url: url)
    }

    func retry() {
        guard let url = currentURL else { return }
        start(url: url)
    }

    private func start(url: URL) {
        configureAudioSession()
        aspectRatio = nil
        let item = AVPlayerItem(url: url)
        observe(item: item)
        player.replaceCurrentItem(with: item)
        state = .buffering
        player.play()
    }

    func play() { player.play() }
    func pause() { player.pause() }

    // MARK: - Observers

    private func observe(item: AVPlayerItem) {
        invalidateObservers()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in self?.handleStatusChange(of: item) }
        }

        // timeControlStatus is what tells playing vs. buffering apart.
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in self?.handleTimeControlChange(of: player) }
        }

        presentationSizeObservation = item.observe(\.presentationSize, options: [.new, .initial]) { [weak self] item, _ in
            let size = item.presentationSize
            Task { @MainActor in self?.updateAspectRatio(from: size) }
        }

        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.state = .ended }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                Task { @MainActor in self?.fail(with: error) }
            }
        )
        notificationTokens.append(
            center.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in if self?.state == .playing { self?.state = .buffering } }
            }
        )
    }

    private func handleStatusChange(of item: AVPlayerItem) {
        if item.status == .failed { fail(with: item.error) }
    }

    private func handleTimeControlChange(of player: AVPlayer) {
        if case .failed = state { return }   // don't override a terminal failure
        switch player.timeControlStatus {
        case .waitingToPlayAtSpecifiedRate:
            state = .buffering
        case .playing:
            state = .playing
        case .paused:
            state = (state == .ended) ? .ended : .paused
        @unknown default:
            break
        }
    }

    private func updateAspectRatio(from size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        aspectRatio = size.width / size.height
    }

    private func fail(with error: Error?) {
        #if DEBUG
        if let error { print("▶️ playback error: \(error)") }
        #endif
        state = .failed(Self.userMessage(for: error))
    }

    // Keep raw codes like "CoreMediaErrorDomain -12938" out of the UI.
    private static func userMessage(for error: Error?) -> String {
        guard let nsError = error as NSError? else {
            return "This video couldn't be played. Please try again."
        }
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "You appear to be offline. Check your connection and try again."
            case NSURLErrorTimedOut:
                return "The video timed out while loading. Please try again."
            default:
                return "We couldn't reach this video. Check your connection and try again."
            }
        }
        return "This video couldn't be played. It may be unavailable or in an unsupported format."
    }

    // MARK: - Teardown

    func tearDown() {
        player.pause()
        invalidateObservers()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
    }

    private func invalidateObservers() {
        statusObservation?.invalidate(); statusObservation = nil
        timeControlObservation?.invalidate(); timeControlObservation = nil
        presentationSizeObservation?.invalidate(); presentationSizeObservation = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    deinit {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
        presentationSizeObservation?.invalidate()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
