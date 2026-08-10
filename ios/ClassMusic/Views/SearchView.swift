import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SearchViewModel()
    @State private var playlistSheetResult: YouTubeSearchResult?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                ForEach(viewModel.results) { result in
                    Button {
                        Task { await playback.play(song: SongRepository.upsert(from: result, context: modelContext)) }
                    } label: {
                        SearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                            queueStore.enqueue(SongRepository.upsert(from: result, context: modelContext))
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Playlist", systemImage: "plus") {
                            playlistSheetResult = result
                        }
                        .tint(.indigo)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.isSearching {
                    ProgressView()
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Songs, artists")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.queryChanged()
            }
            .sheet(item: $playlistSheetResult) { result in
                AddToPlaylistSheet(song: SongRepository.upsert(from: result, context: modelContext))
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test Playback") {
                        Task {
                            let song = Song(
                                id: "dQw4w9WgXcQ",
                                title: "Never Gonna Give You Up",
                                artist: "Rick Astley",
                                thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
                            )
                            await playback.play(song: song)
                        }
                    }
                    .accessibilityIdentifier("debugTestPlaybackButton")
                }
            }
            #endif
        }
    }
}

private struct SearchResultRow: View {
    let result: YouTubeSearchResult

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .lineLimit(1)
                Text(result.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}
