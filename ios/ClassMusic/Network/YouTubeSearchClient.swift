import Foundation

struct YouTubeSearchResult: Identifiable, Hashable {
    let id: String  // video ID
    let title: String
    let artist: String  // channel title — best available proxy without a music-metadata API
    let thumbnailURL: URL?
}

/// Talks directly to the YouTube Data API v3 (free tier, ~100 search units/day
/// on the default quota) to search for tracks by title/artist. Actual audio
/// resolution happens separately, via ResolveClient -> the backend.
struct YouTubeSearchClient {
    private let session: URLSession
    private let apiKey: String

    init(session: URLSession = .shared, apiKey: String = Secrets.youtubeAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func search(query: String, maxResults: Int = 25) async throws -> [YouTubeSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"),  // Music
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
            return decoded.items.compactMap { item in
                guard let videoId = item.id.videoId else { return nil }
                return YouTubeSearchResult(
                    id: videoId,
                    title: item.snippet.title.htmlEntityDecoded,
                    artist: item.snippet.channelTitle.htmlEntityDecoded,
                    thumbnailURL: item.snippet.thumbnails.best
                )
            }
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}

// MARK: - Raw YouTube Data API v3 response shapes

private struct YouTubeSearchResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: ID
        let snippet: Snippet

        struct ID: Decodable {
            let videoId: String?
        }

        struct Snippet: Decodable {
            let title: String
            let channelTitle: String
            let thumbnails: Thumbnails

            struct Thumbnails: Decodable {
                let `default`: Thumbnail?
                let medium: Thumbnail?
                let high: Thumbnail?

                struct Thumbnail: Decodable {
                    let url: String
                }

                var best: URL? {
                    let urlString = high?.url ?? medium?.url ?? `default`?.url
                    return urlString.flatMap(URL.init(string:))
                }
            }
        }
    }
}

private extension String {
    /// YouTube titles frequently contain HTML entities (&amp;, &#39;, ...).
    /// NSAttributedString's HTML decoder needs the main thread (it's backed
    /// by WebKit) and is overkill here, so just handle the common entities.
    var htmlEntityDecoded: String {
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&#39;", "'"), ("&quot;", "\""),
            ("&lt;", "<"), ("&gt;", ">"), ("&apos;", "'"),
        ]
        return entities.reduce(self) { result, pair in
            result.replacingOccurrences(of: pair.0, with: pair.1)
        }
    }
}
