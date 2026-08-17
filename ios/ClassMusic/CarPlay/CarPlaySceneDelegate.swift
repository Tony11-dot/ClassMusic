import CarPlay
import SwiftData

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let tabBar = CPTabBarTemplate(templates: [playlistsTemplate(), CPNowPlayingTemplate.shared])
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    private func playlistsTemplate() -> CPListTemplate {
        let context = ModelContext(ModelContainerHolder.shared)
        let playlists = (try? context.fetch(
            FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []

        let items = playlists.map { playlist -> CPListItem in
            let item = CPListItem(text: playlist.name, detailText: "\(playlist.items.count) songs")
            item.handler = { [weak self] _, completion in
                self?.pushSongs(of: playlist)
                completion()
            }
            return item
        }
        return CPListTemplate(title: "Playlists", sections: [CPListSection(items: items)])
    }

    private func pushSongs(of playlist: Playlist) {
        let songs = playlist.orderedItems.compactMap(\.song)
        let items = songs.enumerated().map { index, song -> CPListItem in
            let item = CPListItem(text: song.title, detailText: song.artist)
            item.handler = { [weak self] _, completion in
                // Route through QueueStore, not PlaybackManager directly —
                // this is the same "playNow" contract every other list (phone
                // Search/Library/Favorites) uses. Calling PlaybackManager
                // alone changed what was audible without moving the queue's
                // own currentIndex, so the *next* auto-advance/skip resumed
                // from wherever the queue had been left, not from this
                // playlist — surfacing on the phone as the queue jumping to
                // an unrelated track ("skips") right after a CarPlay pick.
                if let started = QueueStore.shared?.playNow(songs, startingAt: index) {
                    Task { await PlaybackManager.shared?.play(song: started) }
                }
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            return item
        }
        let template = CPListTemplate(title: playlist.name, sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
}
