import Foundation

enum Secrets {
    static let youtubeAPIKey = string("YOUTUBE_API_KEY")
    static let backendBaseURL = URL(string: string("BACKEND_BASE_URL"))!
    static let backendAPIKey = string("BACKEND_API_KEY")

    private static func string(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
