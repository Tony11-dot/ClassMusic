import Foundation

/// Widget buttons run in the widget extension's process, which has no
/// access to the app's live AVPlayer. Darwin notifications are the
/// documented way to signal a *running* (foreground or backgrounded-while-
/// playing, thanks to the audio background mode) app process from another
/// process in the same App Group. If the app has been fully terminated by
/// the system, a widget tap can't restart playback — same limitation any
/// non-launching interactive widget has.
enum WidgetCommand: String {
    case togglePlayPause = "com.classmate.music.widget.togglePlayPause"
    case skipNext = "com.classmate.music.widget.skipNext"
    case skipPrevious = "com.classmate.music.widget.skipPrevious"

    var darwinName: CFString {
        rawValue as CFString
    }

    func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName),
            nil, nil, true
        )
    }
}
