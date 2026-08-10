import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let status, let body):
            return "Request failed (\(status)): \(body)"
        case .decoding(let error):
            return "Couldn't parse the server's response: \(error.localizedDescription)"
        }
    }
}
