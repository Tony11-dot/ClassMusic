import Foundation

struct ResolvedStream: Decodable {
    let id: String
    let streamURL: URL
    let title: String?
    let artist: String?
    let duration: Double?
    let thumbnail: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, duration, thumbnail
        case streamURL = "stream_url"
    }
}

/// Talks to the self-hosted resolve backend (see backend/app/main.py), which
/// turns a YouTube video ID into a direct, AVPlayer-playable AAC stream URL.
struct ResolveClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    init(
        session: URLSession = .shared,
        baseURL: URL = Secrets.backendBaseURL,
        apiKey: String = Secrets.backendAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// Hits /health first. Free-tier hosts (Render) spin down when idle, so
    /// callers should show a "waking up..." state while this is in flight —
    /// it can take 15-30s on a cold instance.
    func wake() async -> Bool {
        let url = baseURL.appendingPathComponent("health")
        guard let (_, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(http.statusCode)
    }

    func resolve(videoId: String) async throws -> ResolvedStream {
        var url = baseURL.appendingPathComponent("resolve")
        url.append(queryItems: [URLQueryItem(name: "id", value: videoId)])

        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            return try JSONDecoder().decode(ResolvedStream.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}
