import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Song> { $0.lastPlayedAt != nil }, sort: \Song.lastPlayedAt, order: .reverse)
    private var recentSongs: [Song]
    @State private var viewModel = SearchViewModel()
    @State private var playlistSheetResult: YouTubeSearchResult?
    @State private var playlistSheetSong: Song?

    /// Capped so "recently played" stays a quick-access strip, not a second
    /// full history browser — the Library tab is where the rest lives.
    private var recentlyPlayed: [Song] { Array(recentSongs.prefix(15)) }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                // Only makes sense before a query is typed — once results
                // come in, showing history alongside them is just clutter.
                if viewModel.query.isEmpty && !recentlyPlayed.isEmpty {
                    Section {
                        ForEach(recentlyPlayed) { song in
                            Button {
                                guard let index = recentlyPlayed.firstIndex(where: { $0.id == song.id }),
                                      let toPlay = queueStore.playNow(recentlyPlayed, startingAt: index) else { return }
                                Task { await playback.play(song: toPlay) }
                            } label: {
                                SongRow(song: song)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    song.lastPlayedAt = nil
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                                    queueStore.enqueue(song)
                                }
                                .tint(.blue)
                                Button("Playlist", systemImage: "plus") {
                                    playlistSheetSong = song
                                }
                                .tint(.indigo)
                                Button(song.isFavorite ? "Unlike" : "Like", systemImage: song.isFavorite ? "heart.slash" : "heart") {
                                    song.isFavorite.toggle()
                                }
                                .tint(.pink)
                            }
                        }
                    } header: {
                        Text("Recently Played").font(settings.font.font(size: 13))
                    }
                }

                ForEach(viewModel.results) { result in
                    Button {
                        // Upserting the whole visible results list (not just
                        // the tapped row) and handing it to the queue as one
                        // block is what makes Next/Previous walk through
                        // "the list you tapped into" afterward, matching
                        // Spotify/Apple Music — playing a single song here
                        // used to leave the queue's context pointing at
                        // whatever was queued earlier (or nothing), which is
                        // why skip/previous looked broken.
                        let songs = viewModel.results.map { SongRepository.upsert(from: $0, context: modelContext) }
                        guard let index = songs.firstIndex(where: { $0.id == result.id }),
                              let toPlay = queueStore.playNow(songs, startingAt: index) else { return }
                        Task { await playback.play(song: toPlay) }
                    } label: {
                        SongRow(title: result.title, artist: result.artist, thumbnailURL: result.thumbnailURL)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
            .scrollContentBackground(.hidden)
            .background(settings.theme.surface)
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // Placed in the nav bar itself (not a List safeAreaInset)
                // so it sits above the search field drawer, not below it —
                // `.searchable` otherwise fuses the field into the bar,
                // which would put it above any content-level inset.
                ToolbarItem(placement: .principal) { BrandHeaderBar() }
            }
            .overlay {
                // Only the empty state depends on hasSearchedCurrentQuery —
                // without it, this flashed "No results" on every keystroke,
                // before the debounced search had even run.
                if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    if viewModel.hasSearchedCurrentQuery && !viewModel.isSearching {
                        ContentUnavailableView.search(text: viewModel.query)
                    } else {
                        BrandLoader(size: 44, tint: settings.theme.accent)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.isSearching && !viewModel.results.isEmpty {
                    BrandLoader(size: 24, tint: settings.theme.accent)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs, artists")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.queryChanged()
            }
            .sheet(item: $playlistSheetResult) { result in
                AddToPlaylistSheet(song: SongRepository.upsert(from: result, context: modelContext))
            }
            .sheet(item: $playlistSheetSong) { song in
                AddToPlaylistSheet(song: song)
            }
            #if DEBUG
            .task {
                // Driven by SIMCTL_CHILD_UITEST_SEARCH=<query> — exercises
                // the real YouTubeSearchClient path (not just the known-good
                // test track) to verify the production API key end-to-end.
                guard let query = ProcessInfo.processInfo.environment["UITEST_SEARCH"], !query.isEmpty else { return }
                viewModel.query = query
                viewModel.queryChanged()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test") {
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
                    .font(settings.font.font(size: 13))
                    .accessibilityIdentifier("debugTestPlaybackButton")
                }
            }
            #endif
        }
    }
}
