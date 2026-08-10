import UIKit

/// Only exists to route the CarPlay scene to CarPlaySceneDelegate. The
/// default window scene has no matching entry in the Info.plist manifest
/// on purpose — returning a plain UISceneConfiguration for it here (no
/// delegateClass override) lets SwiftUI's own App lifecycle keep handling
/// it exactly as it did before CarPlay support was added, rather than
/// requiring a hand-written UIWindowSceneDelegate + UIHostingController.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            return UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
