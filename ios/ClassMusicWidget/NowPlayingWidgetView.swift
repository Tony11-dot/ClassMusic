import SwiftUI
import WidgetKit

private func artworkImage(for snapshot: NowPlayingSnapshot) -> Image? {
    guard let fileName = snapshot.artworkFileName,
          let uiImage = UIImage(contentsOfFile: NowPlayingStore.artworkURL(fileName: fileName).path)
    else { return nil }
    return Image(uiImage: uiImage)
}

struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: NowPlayingSnapshot

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(snapshot: snapshot)
        case .systemMedium:
            MediumView(snapshot: snapshot)
        case .accessoryCircular:
            CircularAccessoryView(snapshot: snapshot)
        case .accessoryRectangular:
            RectangularAccessoryView(snapshot: snapshot)
        case .accessoryInline:
            InlineAccessoryView(snapshot: snapshot)
        default:
            LargeView(snapshot: snapshot)
        }
    }
}

// MARK: - Home screen: small

private struct SmallView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            Text(snapshot.title)
                .font(.caption.bold())
                .lineLimit(2)
            Text(snapshot.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack {
                Spacer()
                Button(intent: TogglePlayPauseIntent()) {
                    Image(systemName: snapshot.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) {
            background
        }
    }

    @ViewBuilder
    private var background: some View {
        if let image = artworkImage(for: snapshot) {
            image.resizable().aspectRatio(contentMode: .fill)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
        } else {
            Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Home screen: medium

private struct MediumView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title).font(.subheadline.bold()).lineLimit(1)
                Text(snapshot.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                HStack(spacing: 20) {
                    Button(intent: SkipPreviousIntent()) {
                        Image(systemName: "backward.fill")
                    }
                    Button(intent: TogglePlayPauseIntent()) {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button(intent: SkipNextIntent()) {
                        Image(systemName: "forward.fill")
                    }
                }
                .font(.title3)
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let image = artworkImage(for: snapshot) {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
                    .overlay(Image(systemName: "music.note"))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Home screen / StandBy: large

private struct LargeView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        VStack(spacing: 16) {
            Group {
                if let image = artworkImage(for: snapshot) {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay(Image(systemName: "music.note").font(.largeTitle))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 2) {
                Text(snapshot.title).font(.headline).lineLimit(1)
                Text(snapshot.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }

            HStack(spacing: 32) {
                Button(intent: SkipPreviousIntent()) {
                    Image(systemName: "backward.fill")
                }
                Button(intent: TogglePlayPauseIntent()) {
                    Image(systemName: snapshot.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                Button(intent: SkipNextIntent()) {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.title2)
            .buttonStyle(.plain)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen accessories

private struct CircularAccessoryView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        Button(intent: TogglePlayPauseIntent()) {
            Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct RectangularAccessoryView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(snapshot.title).font(.headline).lineLimit(1)
                Text(snapshot.artist).font(.caption).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(intent: TogglePlayPauseIntent()) {
                Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct InlineAccessoryView: View {
    let snapshot: NowPlayingSnapshot

    var body: some View {
        ViewThatFits {
            Label("\(snapshot.title) — \(snapshot.artist)", systemImage: "music.note")
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
