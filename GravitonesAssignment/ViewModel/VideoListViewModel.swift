//
//  VideoListViewModel.swift
//  GravitonesAssignment
//

import Foundation

@MainActor
final class VideoListViewModel: ObservableObject {

    enum State: Equatable {
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published private(set) var videos: [Video] = []
    @Published private(set) var state: State = .loading
    @Published private(set) var isLoadingMore = false

    private let service: VideoService
    private let pageSize = 20
    private var loadedPage = 0
    private var total = 0

    init(service: VideoService = .shared) { self.service = service }

    var canLoadMore: Bool { videos.count < total }

    func loadFirstPageIfNeeded() async {
        guard videos.isEmpty else { return }
        await loadFirstPage()
    }

    func loadFirstPage() async {
        state = .loading
        await fetchFirstPage()
    }

    // Pull-to-refresh: reload page 1 but keep the list if the reload fails.
    func refresh() async {
        await fetchFirstPage(keepingListOnError: true)
    }

    private func fetchFirstPage(keepingListOnError: Bool = false) async {
        do {
            let page = try await service.fetchVideos(page: 1, pageSize: pageSize)
            videos = page.items
            total = page.total
            loadedPage = page.page
            state = page.items.isEmpty ? .empty : .loaded
        } catch {
            if !keepingListOnError || videos.isEmpty {
                state = .error(message(for: error))
            }
        }
    }

    func loadMoreIfNeeded(currentItem: Video) async {
        guard state == .loaded, canLoadMore, !isLoadingMore,
              let index = videos.firstIndex(of: currentItem),
              index >= videos.count - 3 else { return }
        await loadMore()
    }

    private func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.fetchVideos(page: loadedPage + 1, pageSize: pageSize)
            let existingIDs = Set(videos.map(\.id))
            videos.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            total = page.total
            loadedPage = page.page
        } catch {
            // A failed "load more" shouldn't wipe what the user is already viewing.
        }
    }

    private func message(for error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}
