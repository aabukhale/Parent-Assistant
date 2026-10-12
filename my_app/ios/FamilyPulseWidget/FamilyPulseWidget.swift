import SwiftUI
import WidgetKit

/// The Family Pulse payload written by the app (`HomeWidget.saveWidgetData`,
/// key `mamily_surface`, App Group `group.com.mamily.app`). The server
/// already dropped what the parent chose not to show, so every field but the
/// index is optional.
struct PulseSurface: Decodable {
  struct Child: Decodable, Identifiable {
    let id: String
    let index: Int
    let label: String?
    let avatarKey: String?
    let tasksDone: Int?
    let tasksTotal: Int?
    let pendingApprovals: Int?
    let mood: String?
    let points: Int?
    let routineProgress: Double?
    let lastContactState: String?
  }

  let generatedAt: Date?
  let pendingTotal: Int?
  let children: [Child]

  static let appGroup = "group.com.mamily.app"
  static let dataKey = "mamily_surface"

  static func load() -> PulseSurface? {
    guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: dataKey),
          let data = raw.data(using: .utf8) else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { d in
      let text = try d.singleValueContainer().decode(String.self)
      let withFraction = ISO8601DateFormatter()
      withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text) {
        return date
      }
      throw DecodingError.dataCorruptedError(in: try d.singleValueContainer(), debugDescription: text)
    }
    return try? decoder.decode(PulseSurface.self, from: data)
  }
}

struct PulseEntry: TimelineEntry {
  let date: Date
  let surface: PulseSurface?
  /// True once the data is older than [PulseProvider.staleAfter].
  let stale: Bool
}

/// No polling: the app reloads this timeline when it has new data. A second
/// entry flips the widget to "stale" if the app has not refreshed it.
struct PulseProvider: TimelineProvider {
  static let staleAfter: TimeInterval = 2 * 60 * 60

  func placeholder(in context: Context) -> PulseEntry {
    PulseEntry(date: Date(), surface: nil, stale: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
    completion(entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
    let now = Date()
    var entries = [entry(at: now)]
    if let generated = PulseSurface.load()?.generatedAt {
      let staleAt = generated.addingTimeInterval(Self.staleAfter)
      if staleAt > now { entries.append(entry(at: staleAt)) }
    }
    completion(Timeline(entries: entries, policy: .never))
  }

  private func entry(at date: Date) -> PulseEntry {
    let surface = PulseSurface.load()
    let stale = surface?.generatedAt.map { date.timeIntervalSince($0) > Self.staleAfter } ?? true
    return PulseEntry(date: date, surface: surface, stale: stale)
  }
}

struct FamilyPulseWidget: Widget {
  let kind = "FamilyPulseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PulseProvider()) { entry in
      PulseWidgetView(entry: entry)
    }
    .configurationDisplayName(Text("pulse.title"))
    .description(Text("pulse.description"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private enum Palette {
  static let surface = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF3 / 255)
  static let ink = Color(red: 0x2E / 255, green: 0x3B / 255, blue: 0x63 / 255)
  static let muted = Color(red: 0x4F / 255, green: 0x58 / 255, blue: 0x72 / 255)
  static let brand = Color(red: 0xB3 / 255, green: 0x31 / 255, blue: 0x1F / 255)
}

struct PulseWidgetView: View {
  let entry: PulseEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .widgetURL(URL(string: entry.surface == nil ? "mamily://open" : "mamily://open/parent/inbox"))
      .modifier(PulseBackground())
  }

  @ViewBuilder private var content: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("pulse.title")
        .font(.caption.weight(.bold))
        .foregroundColor(Palette.brand)
      if let surface = entry.surface {
        Text(headline(surface))
          .font(.headline)
          .foregroundColor(Palette.ink)
          .lineLimit(2)
        if family != .systemSmall {
          ForEach(surface.children.prefix(3)) { child in
            Text(childLine(child))
              .font(.caption)
              .foregroundColor(Palette.ink)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        footer(surface)
      } else {
        Spacer(minLength: 0)
        Text("pulse.signedOut")
          .font(.caption)
          .foregroundColor(Palette.muted)
      }
    }
  }

  @ViewBuilder private func footer(_ surface: PulseSurface) -> some View {
    if entry.stale || surface.generatedAt == nil {
      Text("pulse.stale")
        .font(.caption2)
        .foregroundColor(Palette.muted)
        .lineLimit(2)
    } else if let generated = surface.generatedAt {
      // Counts up by itself ("5 min") without waking the app.
      (Text("pulse.updated") + Text(" ") + Text(generated, style: .relative))
        .font(.caption2)
        .foregroundColor(Palette.muted)
        .lineLimit(1)
    }
  }

  private func headline(_ surface: PulseSurface) -> String {
    guard let pending = surface.pendingTotal else {
      return String(localized: "pulse.title")
    }
    if pending == 0 { return String(localized: "pulse.allCaughtUp") }
    return String(localized: "pulse.waiting \(pending)")
  }

  private func childLine(_ c: PulseSurface.Child) -> String {
    var parts: [String] = []
    let name = c.label ?? String(localized: "pulse.child \(c.index)")
    parts.append([avatarEmoji(c.avatarKey), name].compactMap { $0 }.joined(separator: " "))
    if let done = c.tasksDone, let total = c.tasksTotal {
      parts.append("\(done)/\(total) " + String(localized: "pulse.tasks"))
    }
    if let progress = c.routineProgress {
      parts.append("🧩 \(Int(progress * 100))%")
    }
    if let pending = c.pendingApprovals, pending > 0 {
      parts.append(String(localized: "pulse.toReview \(pending)"))
    }
    if let mood = c.mood { parts.append(moodEmoji(mood)) }
    if let points = c.points { parts.append("\(points) ⭐") }
    if c.lastContactState == "offline" { parts.append(String(localized: "pulse.noContact")) }
    // Not "·" in Arabic: it looks like the Arabic-Indic zero.
    return parts.joined(separator: String(localized: "pulse.separator"))
  }
}

/// iOS 17 widgets need a container background; earlier versions draw it.
private struct PulseBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(Palette.surface, for: .widget)
    } else {
      content.padding().background(Palette.surface)
    }
  }
}

/// Mirrors `ChildAvatar.emoji` in the Flutter app.
func avatarEmoji(_ key: String?) -> String? {
  switch key {
  case "cat": return "🐱"
  case "bunny": return "🐰"
  case "panda": return "🐼"
  case "lion": return "🦁"
  case "whale": return "🐳"
  case "dino": return "🦕"
  case "robot": return "🤖"
  case "unicorn": return "🦄"
  case "astronaut": return "🧑‍🚀"
  default: return nil
  }
}

/// Mirrors `moodEmoji` in the Flutter app.
func moodEmoji(_ mood: String) -> String {
  switch mood {
  case "great": return "🤩"
  case "happy": return "😊"
  case "tired": return "🥱"
  case "sad": return "😢"
  case "worried": return "😟"
  case "angry": return "😠"
  default: return "🙂"
  }
}
