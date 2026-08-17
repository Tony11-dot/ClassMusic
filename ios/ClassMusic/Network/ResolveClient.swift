import Foundation

struct ResolvedStream {
    let id: String
    /// Always our own backend's /stream endpoint, never the raw googlevideo
    /// URL — see the comment on ResolveClient.resolve below for why.
    let streamURL: URL
    let title: String?
    let artist: String?
    let duration: Double?
    let thumbnail: URL?
    /// Headers AVURLAsset must send with streamURL (the backend's X-API-Key
    /// auth, since a plain AVPlayerItem(url:) can't attach custom headers).
    let streamHeaders: [String: String]
}

/// Talks to the self-hosted resolve backend (see backend/app/main.py), which
/// turns a YouTube video ID into a direct, AVPlayer-playable AAC stream.
struct ResolveClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String

    init(
        session: URLSession = ResolveClient.makeSession(),
        baseURL: URL = Secrets.backendBaseURL,
        apiKey: String = Secrets.backendAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// `.shared`'s default 60s request timeout races the backend's
    /// cookie-authenticated fallback path (bot-walled videos, ~20-25s
    /// server-side on its own) plus yt-dlp's extraction time, which grows
    /// with the video — a long concert/DJ set can blow past 60s even though
    /// the backend would have answered fine. This is a plain request/response
    /// timeout (distinct from AVPlayer's own duration-scaled timeout in
    /// PlaybackManager, which only starts once resolve() has already
    /// succeeded), so it needs its own generous ceiling.
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
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

    /// Fetches metadata from /resolve, but ignores its `stream_url` field —
    /// that's the raw googlevideo URL, and YouTube's CDN signs it with the
    /// requesting IP baked into `sparams`. Handing that straight to AVPlayer
    /// on the phone gets rejected, since the phone's IP isn't the backend's.
    /// Playback goes through /stream instead, which proxies the audio bytes
    /// through the same backend process/IP that resolved them.
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
            // FastAPI error bodies are {"detail": "..."} — surface that
            // human-readable string instead of the raw JSON blob, since this
            // ends up straight in a user-facing alert.
            let detail = (try? JSONDecoder().decode(ErrorDetail.self, from: data))?.detail
            throw NetworkError.http(status: http.statusCode, body: detail ?? String(data: data, encoding: .utf8) ?? "")
        }

        let metadata: ResolveMetadata
        do {
            metadata = try JSONDecoder().decode(ResolveMetadata.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }

        var streamURL = baseURL.appendingPathComponent("stream")
        streamURL.append(queryItems: [URLQueryItem(name: "id", value: videoId)])
        let headers = apiKey.isEmpty ? [:] : ["X-API-Key": apiKey]

        return ResolvedStream(
            id: metadata.id,
            streamURL: streamURL,
            title: metadata.title,
            artist: metadata.artist,
            duration: metadata.duration,
            thumbnail: metadata.thumbnail,
            streamHeaders: headers
        )
    }
}

private struct ErrorDetail: Decodable {
    let detail: String
}

private struct ResolveMetadata: Decodable {
    let id: String
    let title: String?
    let artist: String?
    let duration: Double?
    let thumbnail: URL?
}
