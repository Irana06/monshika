import SwiftUI
import WidgetKit

// Widget beranda iOS untuk Monshika.
// Data ditulis oleh Flutter (home_widget) ke App Group yang sama.

private let appGroupId = "group.com.shicomp.monshika"

private enum Wa {
    static let sumi = Color(red: 15 / 255, green: 15 / 255, blue: 20 / 255)
    static let washi = Color(red: 237 / 255, green: 230 / 255, blue: 214 / 255)
    static let muted = Color(red: 154 / 255, green: 148 / 255, blue: 138 / 255)
    static let kin = Color(red: 201 / 255, green: 164 / 255, blue: 92 / 255)
    static let income = Color(red: 156 / 255, green: 196 / 255, blue: 143 / 255)
    static let expense = Color(red: 224 / 255, green: 96 / 255, blue: 90 / 255)
}

struct MonshikaEntry: TimelineEntry {
    let date: Date
    let data: [String: Any]

    func str(_ key: String, _ fallback: String = "–") -> String {
        (data[key] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    func int(_ key: String) -> Int { (data[key] as? NSNumber)?.intValue ?? 0 }

    func bool(_ key: String) -> Bool { (data[key] as? NSNumber)?.boolValue ?? false }

    func jsonArray(_ key: String) -> [[String: Any]] {
        guard let raw = data[key] as? String, let d = raw.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return arr
    }

    func jsonObject(_ key: String) -> [String: Any]? {
        guard let raw = data[key] as? String, let d = raw.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }
}

struct MonshikaProvider: TimelineProvider {
    private func load() -> MonshikaEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return MonshikaEntry(date: Date(), data: defaults?.dictionaryRepresentation() ?? [:])
    }

    func placeholder(in context: Context) -> MonshikaEntry { MonshikaEntry(date: Date(), data: [:]) }

    func getSnapshot(in context: Context, completion: @escaping (MonshikaEntry) -> Void) { completion(load()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonshikaEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [load()], policy: .after(next)))
    }
}

/// `homeWidget` di query wajib agar HomeWidget.widgetClicked di Flutter menerimanya.
private func deepLink(_ path: String) -> URL { URL(string: "monshika://\(path)\(path.contains("?") ? "&" : "?")homeWidget")! }

private extension View {
    func monshikaBackground() -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(containerBackground(for: .widget) { Wa.sumi })
        }
        return AnyView(padding().background(Wa.sumi))
    }
}

// MARK: - Ringkasan

struct SummaryView: View {
    let entry: MonshikaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("総資産 · Monshika").font(.system(size: 11, design: .serif)).foregroundColor(Wa.kin)
                Spacer()
                Text(entry.str("month_label", "")).font(.system(size: 11)).foregroundColor(Wa.muted)
            }
            Text(entry.str("total_balance", "Buka Monshika"))
                .font(.system(size: 24, weight: .bold, design: .serif)).foregroundColor(Wa.washi)
                .minimumScaleFactor(0.6).lineLimit(1)
            HStack {
                Text("入 \(entry.str("income"))").foregroundColor(Wa.income)
                Spacer()
                Text("出 \(entry.str("expense"))").foregroundColor(Wa.expense)
            }.font(.system(size: 12))
            Text("今日 sisa aman \(entry.str("safe_today_left"))")
                .font(.system(size: 12)).foregroundColor(entry.bool("safe_over") ? Wa.expense : Wa.kin)
            Spacer(minLength: 2)
            HStack(spacing: 8) {
                Link(destination: deepLink("add?type=expense")) {
                    Text("− Pengeluaran").frame(maxWidth: .infinity, minHeight: 30)
                        .background(Wa.expense.opacity(0.18)).foregroundColor(Wa.expense).cornerRadius(10)
                }
                Link(destination: deepLink("add?type=income")) {
                    Text("+ Pemasukan").frame(maxWidth: .infinity, minHeight: 30)
                        .background(Wa.income.opacity(0.18)).foregroundColor(Wa.income).cornerRadius(10)
                }
            }.font(.system(size: 12, weight: .bold))
        }
        .monshikaBackground()
    }
}

struct SummaryWidget: Widget {
    let kind = "SummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { SummaryView(entry: $0) }
            .configurationDisplayName("Ringkasan")
            .description("Total saldo, arus kas bulan ini, dan tombol cepat.")
            .supportedFamilies([.systemMedium])
    }
}

// MARK: - Catat cepat & sisa aman

struct QuickAddView: View {
    let entry: MonshikaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日 · sisa aman").font(.system(size: 11, design: .serif)).foregroundColor(Wa.kin)
            Text(entry.str("safe_today_left"))
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(entry.bool("safe_over") ? Wa.expense : Wa.washi)
                .minimumScaleFactor(0.6).lineLimit(1)
            ProgressView(value: Double(min(100, max(0, entry.int("safe_ratio")))), total: 100).tint(Wa.kin)
            Text("Jatah \(entry.str("safe_per_day"))/hari").font(.system(size: 10)).foregroundColor(Wa.muted)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Link(destination: deepLink("add?type=expense")) {
                    Text("− 出").frame(maxWidth: .infinity, minHeight: 28).background(Wa.expense.opacity(0.18)).foregroundColor(Wa.expense).cornerRadius(9)
                }
                Link(destination: deepLink("add?type=income")) {
                    Text("+ 入").frame(maxWidth: .infinity, minHeight: 28).background(Wa.income.opacity(0.18)).foregroundColor(Wa.income).cornerRadius(9)
                }
            }.font(.system(size: 13, weight: .bold, design: .serif))
        }
        .monshikaBackground()
    }
}

struct QuickAddWidget: Widget {
    let kind = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { QuickAddView(entry: $0) }
            .configurationDisplayName("Catat Cepat & Sisa Aman")
            .description("Sisa aman hari ini dan tombol catat.")
            .supportedFamilies([.systemSmall])
    }
}

// MARK: - Budget & tagihan

struct BudgetView: View {
    let entry: MonshikaEntry

    var body: some View {
        let items = entry.jsonArray("budgets")
        VStack(alignment: .leading, spacing: 6) {
            Text("算 Budget").font(.system(size: 12, design: .serif)).foregroundColor(Wa.kin)
            if items.isEmpty {
                Spacer()
                Text("Belum ada budget").font(.system(size: 12)).foregroundColor(Wa.muted).frame(maxWidth: .infinity)
                Spacer()
            }
            ForEach(0..<min(3, items.count), id: \.self) { i in
                let o = items[i]
                let pct = (o["pct"] as? NSNumber)?.intValue ?? 0
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(o["icon"] as? String ?? "")  \(o["name"] as? String ?? "")").foregroundColor(Wa.washi).lineLimit(1)
                        Spacer()
                        Text("\(pct)%").bold().foregroundColor(pct >= 100 ? Wa.expense : Wa.kin)
                    }.font(.system(size: 12))
                    ProgressView(value: Double(min(100, max(0, pct))), total: 100).tint(pct >= 100 ? Wa.expense : Wa.kin)
                }
            }
        }
        .monshikaBackground()
    }
}

struct BudgetWidget: Widget {
    let kind = "BudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { BudgetView(entry: $0) }
            .configurationDisplayName("Budget")
            .description("Budget dengan pemakaian tertinggi.")
            .supportedFamilies([.systemMedium])
    }
}

struct UpcomingView: View {
    let entry: MonshikaEntry

    var body: some View {
        let items = entry.jsonArray("upcoming")
        VStack(alignment: .leading, spacing: 5) {
            Text("予 14 hari ke depan").font(.system(size: 12, design: .serif)).foregroundColor(Wa.kin)
            if items.isEmpty {
                Spacer()
                Text("Tidak ada tagihan 🎐").font(.system(size: 12)).foregroundColor(Wa.muted).frame(maxWidth: .infinity)
                Spacer()
            }
            ForEach(0..<min(4, items.count), id: \.self) { i in
                let o = items[i]
                let income = (o["income"] as? NSNumber)?.boolValue ?? false
                HStack(spacing: 6) {
                    Text(o["icon"] as? String ?? "").font(.system(size: 13, weight: .bold, design: .serif)).foregroundColor(Wa.kin).frame(width: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(o["title"] as? String ?? "").font(.system(size: 12)).foregroundColor(Wa.washi).lineLimit(1)
                        Text(o["date"] as? String ?? "").font(.system(size: 10)).foregroundColor(Wa.muted)
                    }
                    Spacer()
                    Text("\(income ? "+" : "−")\(o["amount"] as? String ?? "")").font(.system(size: 12, weight: .bold)).foregroundColor(income ? Wa.income : Wa.expense)
                }
            }
        }
        .monshikaBackground()
    }
}

struct UpcomingWidget: Widget {
    let kind = "UpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { UpcomingView(entry: $0) }
            .configurationDisplayName("Tagihan Mendatang")
            .description("Tagihan, cicilan & jatuh tempo 14 hari.")
            .supportedFamilies([.systemMedium])
    }
}

// MARK: - Target & grafik

struct GoalView: View {
    let entry: MonshikaEntry

    var body: some View {
        let o = entry.jsonObject("goal")
        let pct = (o?["pct"] as? NSNumber)?.intValue ?? 0
        VStack(spacing: 4) {
            Text(o?["icon"] as? String ?? "夢").font(.system(size: 28, weight: .bold, design: .serif)).foregroundColor(Wa.kin)
            Text(o?["name"] as? String ?? "Belum ada target").font(.system(size: 12)).foregroundColor(Wa.washi).lineLimit(1)
            ProgressView(value: Double(pct), total: 100).tint(Wa.kin)
            Text("\(pct)%").font(.system(size: 16, weight: .bold, design: .serif)).foregroundColor(Wa.kin)
            Text("\(o?["saved"] as? String ?? "") / \(o?["target"] as? String ?? "")").font(.system(size: 10)).foregroundColor(Wa.muted).lineLimit(1)
        }
        .monshikaBackground()
    }
}

struct GoalWidget: Widget {
    let kind = "GoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { GoalView(entry: $0) }
            .configurationDisplayName("Target Tabungan")
            .description("Progres target yang disematkan.")
            .supportedFamilies([.systemSmall])
    }
}

struct ChartView: View {
    let entry: MonshikaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("図 7 hari terakhir").font(.system(size: 12, design: .serif)).foregroundColor(Wa.kin)
                Spacer()
                Text(entry.str("week_total", "")).font(.system(size: 12, weight: .bold)).foregroundColor(Wa.expense)
            }
            if let path = entry.data["chart_image"] as? String, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Spacer()
                Text("Buka Monshika untuk memuat grafik").font(.system(size: 11)).foregroundColor(Wa.muted).frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .monshikaBackground()
    }
}

struct ChartWidget: Widget {
    let kind = "ChartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonshikaProvider()) { ChartView(entry: $0) }
            .configurationDisplayName("Grafik 7 Hari")
            .description("Pemasukan & pengeluaran seminggu terakhir.")
            .supportedFamilies([.systemMedium])
    }
}

@main
struct MonshikaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
        QuickAddWidget()
        ChartWidget()
        BudgetWidget()
        UpcomingWidget()
        GoalWidget()
    }
}
