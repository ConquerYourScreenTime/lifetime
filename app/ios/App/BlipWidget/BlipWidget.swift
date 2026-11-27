import WidgetKit
import SwiftUI

// Conquer Your Screen Time widgets (design handoff 2026-11-25, Widgets board; build 4).
//  - Lock Screen: a line above the clock ("Leading 4 of 6 this week"), a ring with points left, and a wide widget
//    showing where points went (Red, Orange, and what the next 15 minutes of Red would cost).
//  - Home small: points left with the Red/Orange bar. Home medium: adds the breakdown and the seals.
//  - After the seal is broken in the app, the widgets turn gold with the crown and "4 of 6" for a few hours.
//    They never show a result before the seal is broken.
//  - Reads only what the app and the Screen Time monitor already save on this phone (App Group). Nothing leaves the phone.

private let group = "group.io.github.gamesbyvidal.lifetime"
private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)      // #0d0d0f
private let ink = Color(red: 0.961, green: 0.945, blue: 0.902)     // #f5f1e6
private let ivory = Color(red: 0.925, green: 0.894, blue: 0.816)   // #ece4d0
private let dim = Color(red: 0.710, green: 0.678, blue: 0.600)     // #b5ad99
private let faint = Color(red: 0.604, green: 0.576, blue: 0.498)   // #9a937f
private let gold = Color(red: 0.788, green: 0.647, blue: 0.290)    // #c9a54a
private let red = Color(red: 0.910, green: 0.416, blue: 0.455)     // #e86a74
private let orange = Color(red: 0.863, green: 0.612, blue: 0.333)  // #dc9c55
private let card = Color(red: 0.110, green: 0.110, blue: 0.129)    // #1c1c21

// Playfair Display Bold (SIL OFL), bundled in this extension and listed under UIAppFonts. Fonts registered at
// run time from the App Group don't reach the Home Screen renderer, which left the Home widgets blank in build 4.
private enum Display {
    static func font(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-Bold", size: size) }
}

private func fmt(_ n: Int) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}
private func hm(_ m: Int) -> String {
    let h = m / 60, mm = m % 60
    if h == 0 { return "\(mm) min" }
    return mm == 0 ? "\(h) hr" : "\(h) hr \(mm)"
}
private func dayString(_ d: Date) -> String {
    let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
}

struct Row: Hashable { let name: String; let diff: Int }

struct ConquerEntry: TimelineEntry {
    let date: Date
    let ready: Bool
    let red: Int        // minutes today, 15-minute steps
    let orange: Int
    let rivals: Int
    let weekLead: Int
    let weekOf: Int
    let gold: Bool      // seal broken in the app: show the result for a few hours
    let held: Int
    let of: Int
    let me: Int
    let rows: [Row]

    var redCost: Int { (red / 15) * 40 }
    var orangeCost: Int { (orange / 15) * 20 }
    var left: Int { max(0, 1000 - redCost - orangeCost) }
    var won: Bool { held * 2 > of }

    static let sample = ConquerEntry(date: Date(), ready: true, red: 75, orange: 30, rivals: 6, weekLead: 4, weekOf: 6,
                                     gold: false, held: 4, of: 6, me: 812, rows: [])
}

struct Provider: TimelineProvider {
    func entry(at date: Date) -> ConquerEntry {
        let d = UserDefaults(suiteName: group)
        let day = dayString(date)
        let info = d?.dictionary(forKey: "conquer-widget") ?? [:]
        let ready = d?.bool(forKey: "friends-ready") == true
        // The result day the app last showed must still be the open one (yesterday from 8 AM).
        let hour = Calendar.current.component(.hour, from: date)
        let openDay = dayString(Calendar.current.date(byAdding: .day, value: hour >= 8 ? -1 : -2, to: date) ?? date)
        let at = Double(info["revealedAt"] as? Int ?? 0)
        let gold = (info["revealed"] as? Bool ?? false) && (info["resultDay"] as? String ?? "") == openDay
            && at > 0 && date.timeIntervalSince1970 < at + 3 * 3600
        let rows = (info["rows"] as? [[String: Any]] ?? []).compactMap { r -> Row? in
            guard let n = r["n"] as? String, let v = r["d"] as? Int else { return nil }
            return Row(name: n, diff: v)
        }
        return ConquerEntry(date: date, ready: ready,
                            red: d?.integer(forKey: "fmin-red-" + day) ?? 0, orange: d?.integer(forKey: "fmin-orange-" + day) ?? 0,
                            rivals: info["rivals"] as? Int ?? 0, weekLead: info["weekLead"] as? Int ?? 0, weekOf: info["weekOf"] as? Int ?? 0,
                            gold: gold, held: info["held"] as? Int ?? 0, of: info["of"] as? Int ?? 0, me: info["me"] as? Int ?? 0, rows: rows)
    }

    func placeholder(in context: Context) -> ConquerEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (ConquerEntry) -> Void) {
        let e = entry(at: Date())
        completion(context.isPreview && !e.ready ? .sample : e)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConquerEntry>) -> Void) {
        let now = Date()
        var dates = [now]
        let cal = Calendar.current
        // Midnight: points start again at 1,000. 8 AM: results open (still sealed). End of the gold window.
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) { dates.append(midnight) }
        if let eight = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now), eight > now { dates.append(eight) }
        let info = UserDefaults(suiteName: group)?.dictionary(forKey: "conquer-widget") ?? [:]
        if let at = info["revealedAt"] as? Int, at > 0 {
            let end = Date(timeIntervalSince1970: Double(at) + 3 * 3600)
            if end > now { dates.append(end) }
        }
        let entries = dates.sorted().filter { $0.timeIntervalSince(now) < 24 * 3600 }.map { entry(at: $0) }
        // The monitor asks for a reload on every new 15-minute step; this is the fallback.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

// MARK: - The crown (the shipped app icon's crown) and the wax seal

private let crownPoints: [[CGPoint]] = [
    "20,66 13,29 34,52", "13,29 34,52 26,66 20,66", "34,52 50,24 50,58", "50,24 66,52 50,58", "34,52 50,58 26,66",
    "66,52 50,58 74,66", "50,58 26,66 74,66", "66,52 87,29 80,66 74,66", "87,29 80,66 74,66", "19,70 81,70 79,74 21,74",
    "21,74 79,74 81,78 19,78", "50,14.9 45.2,20.5 50,20.5", "50,14.9 54.8,20.5 50,20.5", "45.2,20.5 50,26.1 50,20.5",
    "54.8,20.5 50,26.1 50,20.5", "13,20.6 9.2,25.2 13,25.2", "13,20.6 16.8,25.2 13,25.2", "9.2,25.2 13,29.8 13,25.2",
    "16.8,25.2 13,29.8 13,25.2", "87,20.6 83.2,25.2 87,25.2", "87,20.6 90.8,25.2 87,25.2", "83.2,25.2 87,29.8 87,25.2",
    "90.8,25.2 87,29.8 87,25.2",
].map { s in s.split(separator: " ").map { p -> CGPoint in let v = p.split(separator: ",").compactMap { Double($0) }; return CGPoint(x: v[0], y: v[1]) } }
private let crownGold = ["#f2dc97","#d6b55f","#f6e4a8","#b8913a","#c9a54a","#9c772b","#ad8634","#a37d2e","#86641f","#e8cd7e","#9c772b","#fff7dc","#ead38e","#f6e4a8","#b8913a","#fff2c8","#e6cb80","#f2dc97","#d6b55f","#e9d08a","#b89140","#a37d2e","#86641f"]
private let crownPewter = ["#bcb6a5","#9c9788","#c3bcaa","#7e7a6e","#8f8a7d","#69655b","#757167","#6e6a60","#58554d","#b0aa9a","#69655b","#d4cdb9","#b5af9e","#c3bcaa","#7e7a6e","#d0c8b5","#aea898","#bcb6a5","#9c9788","#b3ac9c","#7f7b6f","#6e6a60","#58554d"]

extension Color {
    init(hex: String) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}

// One facet of the crown, in the 84 x 68 box of the icon art. Drawn as plain shapes: Canvas isn't safe in widgets.
struct Facet: Shape {
    let pts: [CGPoint]
    func path(in r: CGRect) -> Path {
        let k = min(r.width / 84, r.height / 68)
        let ox = r.minX + (r.width - 84 * k) / 2, oy = r.minY + (r.height - 68 * k) / 2
        var p = Path()
        p.addLines(pts.map { CGPoint(x: ox + ($0.x - 8) * k, y: oy + ($0.y - 11) * k) })
        p.closeSubpath()
        return p
    }
}

// Lock Screen widgets draw in one tint, so there the crown keeps its facets as shades of white (design handoff
// section 17): each facet's brightness in the gold art becomes its opacity.
private let crownShade: [Double] = crownGold.map { h in
    var s = h; s.removeFirst(); var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    let l = (0.299 * Double((v >> 16) & 0xff) + 0.587 * Double((v >> 8) & 0xff) + 0.114 * Double(v & 0xff)) / 255
    return 0.35 + 0.65 * l
}

struct Crown: View {
    var fills: [String] = crownGold
    var mono: Color? = nil
    var tint = false
    var body: some View {
        ZStack {
            ForEach(0..<crownPoints.count, id: \.self) { i in
                let c = tint ? Color.white.opacity(crownShade[i]) : mono ?? Color(hex: fills[i])
                if mono != nil {
                    Facet(pts: crownPoints[i]).fill(c).overlay(Facet(pts: crownPoints[i]).stroke(c, lineWidth: 0.5))
                } else {
                    Facet(pts: crownPoints[i]).fill(c)
                }
            }
        }
        .aspectRatio(84 / 68, contentMode: .fit)
    }
}

struct Seal: View {
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: "#8a2433"), Color(hex: "#5e1520"), Color(hex: "#3a0b12")],
                                         center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: 30))
            Circle().inset(by: 4).stroke(Color(hex: "#4a0f17"), lineWidth: 1.2)
            Crown(mono: Color(hex: "#9a3a47")).padding(7)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Pieces

struct PointsBar: View {
    let e: ConquerEntry
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                Rectangle().fill(ivory).frame(width: g.size.width * CGFloat(e.left) / 1000)
                Rectangle().fill(orange).frame(width: g.size.width * CGFloat(min(e.orangeCost, 1000)) / 1000)
                Rectangle().fill(red)
            }
        }
        .frame(height: 5).clipShape(Capsule())
    }
}

struct Label11: View {
    let text: String
    var color: Color = faint
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).kerning(1.5).foregroundColor(color) }
}

struct SmallView: View {
    let e: ConquerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Label11(text: "Left today"); Spacer(); Crown().frame(width: 18) }
            Text(fmt(e.left)).font(Display.font(44)).foregroundColor(ink).minimumScaleFactor(0.6).lineLimit(1).privacySensitive()
            Spacer(minLength: 0)
            PointsBar(e: e).privacySensitive()
            Text(e.rivals > 0 ? "Sealed till 8 AM" : "Conquer").font(.system(size: 11)).foregroundColor(faint)
        }
    }
}

struct MediumView: View {
    let e: ConquerEntry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label11(text: "Left today")
                Text(fmt(e.left)).font(Display.font(48)).foregroundColor(ink).minimumScaleFactor(0.6).lineLimit(1).privacySensitive()
                Spacer(minLength: 0)
                PointsBar(e: e).privacySensitive()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                line(red, "Red · " + hm(e.red), e.redCost)
                line(orange, "Orange · " + hm(e.orange), e.orangeCost)
                Divider().background(Color.white.opacity(0.1))
                if e.rivals > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) { ForEach(0..<min(e.rivals, 4), id: \.self) { _ in Seal().frame(width: 20) } }
                        Text("\(e.rivals == 1 ? "Your battle" : "\(e.rivals) battles") sealed till 8 AM").font(.system(size: 11)).foregroundColor(dim).lineLimit(2)
                    }
                } else {
                    Text("Invite a friend to start a battle.").font(.system(size: 11)).foregroundColor(dim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    func line(_ c: Color, _ t: String, _ cost: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t).font(.system(size: 12)).foregroundColor(ink).lineLimit(1)
            Spacer(minLength: 2)
            Text(cost > 0 ? "−\(fmt(cost))" : "0").font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundColor(c).privacySensitive()
        }
    }
}

// After the seal is broken: gold when you won most, pewter otherwise.
struct GoldSmall: View {
    let e: ConquerEntry
    var body: some View {
        VStack(spacing: 4) {
            if e.won { Crown().frame(width: 56) } else { Crown(fills: crownPewter).frame(width: 56) }
            Text("\(e.held) of \(e.of)").font(Display.font(26)).foregroundColor(e.won ? gold : ink)
            Text(e.of == 1 ? (e.held == 1 ? "crown won yesterday" : "crown lost yesterday") : "crowns won yesterday").font(.system(size: 11)).foregroundColor(dim)
        }
    }
}

struct GoldMedium: View {
    let e: ConquerEntry
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label11(text: "Yesterday", color: e.won ? gold : faint)
                Text("\(e.held) of \(e.of)").font(Display.font(34)).foregroundColor(e.won ? gold : ink)
                Text("\(fmt(e.me)) points").font(.system(size: 11)).foregroundColor(dim)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                ForEach(e.rows, id: \.self) { r in
                    HStack(spacing: 4) {
                        if r.diff > 0 { Crown().frame(width: 13) } else { Crown(fills: crownPewter).frame(width: 13) }
                        Text(r.name).font(.system(size: 11)).foregroundColor(r.diff > 0 ? ink : faint).lineLimit(1)
                        Spacer(minLength: 2)
                        Text((r.diff > 0 ? "+" : r.diff < 0 ? "−" : "") + fmt(abs(r.diff))).font(.system(size: 11)).monospacedDigit().foregroundColor(r.diff > 0 ? gold : faint)
                    }
                }
            }
        }
    }
}

// Lock Screen pieces v3 (design handoff section 17; one tint, drawn by iOS). The ring is points left, the wide
// widget is where they went, the crown is on both. Results only after the seal is broken in the app.
struct LockRing: View {
    let e: ConquerEntry
    var body: some View {
        Gauge(value: Double(e.left), in: 0...1000) {
            Text("LEFT")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Crown(tint: true).frame(width: 15).opacity(e.left == 0 ? 0.45 : 1)
                Text(fmt(e.left)).font(Display.font(15)).minimumScaleFactor(0.5).lineLimit(1)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .privacySensitive()
    }
}

struct LockBar: View {
    let e: ConquerEntry
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                if e.gold { Rectangle().fill(Color.white) } else {
                    Rectangle().fill(Color.white).frame(width: g.size.width * CGFloat(e.left) / 1000)
                    Rectangle().fill(Color.white.opacity(0.55)).frame(width: g.size.width * CGFloat(min(e.orangeCost, 1000)) / 1000)
                    Rectangle().fill(Color.white.opacity(0.32))
                }
            }
        }
        .frame(height: 4).clipShape(Capsule())
    }
}

struct LockRect: View {
    let e: ConquerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Crown(tint: true).frame(width: 14).opacity(!e.gold && e.left == 0 ? 0.45 : 1)
                if e.gold && e.of > 0 {
                    Text("\(e.held) of \(e.of)").font(Display.font(15)).lineLimit(1)
                    Text("CROWNS WON YESTERDAY").font(.system(size: 9, weight: .semibold)).kerning(1.1).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text(e.left == 0 ? "ALL SPENT · BACK AT MIDNIGHT" : "WHERE POINTS WENT").font(.system(size: 10, weight: .semibold)).kerning(1.2).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            LockBar(e: e)
            Group {
                if e.gold && e.of > 0 { Text("Fresh 1,000 points today") }
                else { Text("Red −\(fmt(e.redCost)) · Orange −\(fmt(e.orangeCost))") }
            }
            .font(.system(size: 12)).opacity(0.8).lineLimit(1).minimumScaleFactor(0.8)
        }
        .privacySensitive()
    }
}

struct LockLine: View {
    let e: ConquerEntry
    var body: some View {
        if e.gold { Text(Image(systemName: "crown.fill")) + Text(" \(e.held) of \(e.of) crowns yesterday") }
        else if e.weekOf > 0 { Text(Image(systemName: "crown.fill")) + Text(e.weekLead > 0 ? " Leading \(e.weekLead) of \(e.weekOf) this week" : " Chasing \(e.weekOf) this week") }
        else { Text("\(fmt(e.left)) points left") }
    }
}

struct SetupView: View {
    var body: some View {
        VStack(spacing: 6) {
            Crown().frame(width: 34)
            Text("Open Conquer to set up.").font(.system(size: 11)).foregroundColor(dim).multilineTextAlignment(.center)
        }
    }
}

struct ConquerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let e: ConquerEntry
    var body: some View {
        Group {
            switch family {
            case .accessoryInline: LockLine(e: e)
            case .accessoryCircular: LockRing(e: e)
            case .accessoryRectangular: LockRect(e: e)
            default:
                if !e.ready { SetupView() }
                else if e.gold && e.of > 0 { if family == .systemMedium { GoldMedium(e: e) } else { GoldSmall(e: e) } }
                else if family == .systemMedium { MediumView(e: e) }
                else { SmallView(e: e) }
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular || family == .accessoryCircular || family == .accessoryInline { Color.clear }
            else if e.gold && e.won {
                ZStack { bg; LinearGradient(colors: [Color(hex: "#2a2418"), bg], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ContainerRelativeShape().inset(by: 4).stroke(gold.opacity(0.45), lineWidth: 1) }
            } else { bg }
        }
    }
}

struct BlipWidget: Widget {
    var body: some WidgetConfiguration {
        // Kind kept from earlier builds so widgets already on a Home Screen keep working.
        StaticConfiguration(kind: "BlipCount", provider: Provider()) { e in
            ConquerWidgetView(e: e)
        }
        .configurationDisplayName("Conquer")
        .description("Points left today, where they went, and your crowns once you break the seal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .disfavoredLocations([.iPhoneWidgetsOnMac], for: [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct ConquerWidgets: WidgetBundle {
    var body: some Widget {
        BlipWidget()
    }
}
