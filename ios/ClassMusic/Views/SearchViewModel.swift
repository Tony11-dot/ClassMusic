import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var results: [YouTubeSearchResult] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    private let client: YouTubeSearchClient
    private var searchTask: Task<Void, Never>?

    init(client: YouTubeSearchClient = YouTubeSearchClient()) {
        self.client = client
    }

    /// Debounced so typing doesn't fire a request (100 quota units each,
    /// against a ~100/day free-tier budget) per keystroke.
    func queryChanged() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await runSearch(query: trimmed)
        }
    }

    @MainActor
    private func runSearch(query: String) async {
        isSearching = true
        errorMessage = nil
        do {
            results = try await client.search(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}
