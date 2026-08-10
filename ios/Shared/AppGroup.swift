import Foundation

enum AppGroup {
    static let id = "group.com.classmate.music"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id)!
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)!
    }
}
