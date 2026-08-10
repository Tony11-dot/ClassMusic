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
        let items = playlist.orderedItems.compactMap(\.song).map { song -> CPListItem in
            let item = CPListItem(text: song.title, detailText: song.artist)
            item.handler = { [weak self] _, completion in
                Task { await PlaybackManager.shared?.play(song: song) }
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            return item
        }
        let template = CPListTemplate(title: playlist.name, sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
}
