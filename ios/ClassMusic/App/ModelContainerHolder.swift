import SwiftData

/// CarPlaySceneDelegate is a separate UIKit scene delegate, outside the
/// SwiftUI environment that normally carries the model container — it
/// needs a plain way to get a ModelContext of its own.
enum ModelContainerHolder {
    // Set exactly once, from ClassMusicApp.init() before any scene
    // (including CarPlay) can connect and read it — safe as a one-shot
    // global despite not being actor-isolated.
    nonisolated(unsafe) static var shared: ModelContainer!
}
