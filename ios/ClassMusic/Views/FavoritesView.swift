import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Query(filter: #Predicate<Song> { $0.isFavorite }, sort: \Song.dateAdded, order: .reverse)
    private var favorites: [Song]

    var body: some View {
        List {
            if favorites.isEmpty {
                ContentUnavailableView("No Favorites Yet", systemImage: "heart", description: Text("Tap the heart on any song to add it here."))
            }
            ForEach(favorites) { song in
                Button {
                    Task { await playback.play(song: song) }
                } label: {
                    SongRow(song: song)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Unfavorite", systemImage: "heart.slash") {
                        song.isFavorite = false
                    }
                    .tint(.pink)
                    Button("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                        queueStore.enqueue(song)
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Favorites")
    }
}
