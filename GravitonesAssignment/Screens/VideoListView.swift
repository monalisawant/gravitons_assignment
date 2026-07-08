//
//  VideoListView.swift
//  GravitonesAssignment
//

import SwiftUI

struct VideoListView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = VideoListViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Videos")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let user = auth.currentUser {
                                Text(user.name)
                                // Text(user.email)
                            }
                            Button("Log Out", role: .destructive) {
                                Task { await auth.logout() }
                            }
                        } label: {
                            Image(systemName: "person.circle")
                        }
                    }
                }
        }
        .task { await viewModel.loadFirstPageIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading videos…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView("No Videos", systemImage: "film.stack",
                                   description: Text("There are no videos to show yet."))

        case .error(let message):
            ContentUnavailableView {
                Label("Couldn't Load Videos", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.loadFirstPage() } }
                    .buttonStyle(.borderedProminent)
            }

        case .loaded:
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.videos) { video in
                    row(for: video)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: video) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable { await viewModel.refresh() }
        .navigationDestination(for: Video.self) { VideoPlayerScreen(video: $0) }
    }

    @ViewBuilder
    private func row(for video: Video) -> some View {
        if video.status == .ready {
            NavigationLink(value: video) { VideoRow(video: video) }
                .buttonStyle(.plain)
        } else {
            // PROCESSING / FAILED — visible but not playable.
            VideoRow(video: video)
        }
    }
}

#Preview {
    VideoListView().environmentObject(AuthViewModel())
}
