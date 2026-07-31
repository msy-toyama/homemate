//
//  HomeMateWidget.swift
//  HomeMateWidget
//
//  「次にやること」と今日の残件をやさしく表示するウィジェット。
//  Core Data 本体は読まず、App Group 経由の WidgetSnapshot だけを読む（設計 21.5）。
//

import WidgetKit
import SwiftUI

// MARK: - Deep links

enum WidgetDeepLink {
    static let scheme = "homemate"
    static var board: URL { URL(string: "\(scheme)://board")! }
    static var lists: URL { URL(string: "\(scheme)://lists")! }
    static var add: URL { URL(string: "\(scheme)://add")! }
}

// MARK: - Widget palette（本体デザインシステムと統一。Widget は別ターゲットのため内包）

private enum WP {
    static let accent = Color(red: 0.929, green: 0.451, blue: 0.376)   // coral
    static let accentDeep = Color(red: 0.86, green: 0.38, blue: 0.30)
    static let chore = Color(red: 0.34, green: 0.64, blue: 0.58)        // sage
    static let grocery = Color(red: 0.94, green: 0.62, blue: 0.31)      // amber
    static let request = Color(red: 0.55, green: 0.50, blue: 0.82)      // lavender
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
}

// MARK: - Timeline

struct HomeMateEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct HomeMateProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeMateEntry {
        HomeMateEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeMateEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : WidgetSnapshot.load()
        completion(HomeMateEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeMateEntry>) -> Void) {
        let entry = HomeMateEntry(date: Date(), snapshot: WidgetSnapshot.load())
        // 1時間ごとに更新（アプリ側からも reloadAllTimelines で随時更新される）。
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct HomeMateWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: HomeMateProvider.Entry

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: entry.snapshot)
        case .accessoryInline:
            AccessoryInlineView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetBackground()
        default:
            LinearGradient(
                colors: [WP.accent.opacity(0.10), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Progress ring

private struct WidgetRing: View {
    let progress: Double
    var lineWidth: CGFloat = 7
    var tint: Color = WP.accent
    var trackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    WidgetRing(progress: snapshot.todayProgress, lineWidth: 6)
                    Text("\(Int((snapshot.todayProgress * 100).rounded()))%")
                        .font(.system(size: 13, design: .rounded).weight(.bold))
                        .foregroundStyle(WP.primaryText)
                        .monospacedDigit()
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 1) {
                    Text(WidgetStrings.today)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(WP.accent)
                    Text(progressText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(WP.secondaryText)
                        .monospacedDigit()
                }
            }

            if let title = snapshot.nextTaskTitle {
                Divider().opacity(0.5)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(WP.primaryText)
                    .lineLimit(2)
                if let assignee = snapshot.nextTaskAssigneeName {
                    Text(assignee)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(WP.secondaryText)
                }
            } else {
                Spacer(minLength: 0)
                Label(WidgetStrings.allCaughtUp, systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(WP.chore)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                CountPill(value: snapshot.groceryCount, symbol: "cart.fill", tint: WP.grocery)
                CountPill(value: snapshot.requestCount, symbol: "hand.wave.fill", tint: WP.request)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeepLink.board)
    }

    private var progressText: String {
        String(format: WidgetStrings.progressFraction, snapshot.todayCompletedCount, snapshot.todayTotalCount)
    }
}

private struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label(WidgetStrings.nextUp, systemImage: "sparkles")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(WP.accent)

                if let title = snapshot.nextTaskTitle {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(WP.primaryText)
                        .lineLimit(2)
                    if let assignee = snapshot.nextTaskAssigneeName {
                        Label(assignee, systemImage: "person.fill")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(WP.secondaryText)
                    }
                    if let due = snapshot.nextTaskDueAt {
                        Text(due, style: .relative)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(WP.accentDeep)
                    }
                } else {
                    Label(WidgetStrings.allCaughtUp, systemImage: "checkmark.circle.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(WP.chore)
                }
                Spacer(minLength: 0)

                ZStack {
                    WidgetRing(progress: snapshot.todayProgress, lineWidth: 6, tint: WP.accent)
                    Text("\(Int((snapshot.todayProgress * 100).rounded()))%")
                        .font(.system(size: 12, design: .rounded).weight(.bold))
                        .foregroundStyle(WP.primaryText)
                        .monospacedDigit()
                }
                .frame(width: 38, height: 38)
                .overlay(alignment: .leading) {
                    Text(String(format: WidgetStrings.progressFraction,
                                snapshot.todayCompletedCount, snapshot.todayTotalCount))
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(WP.secondaryText)
                        .monospacedDigit()
                        .offset(x: 46)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 9) {
                StatRow(symbol: "checklist", label: WidgetStrings.today, value: snapshot.todayTaskCount, tint: WP.chore)
                StatRow(symbol: "cart.fill", label: WidgetStrings.groceries, value: snapshot.groceryCount, tint: WP.grocery)
                StatRow(symbol: "hand.wave.fill", label: WidgetStrings.requests, value: snapshot.requestCount, tint: WP.request)
            }
            .frame(width: 140)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeepLink.board)
    }
}

// MARK: - Lock screen accessories

private struct AccessoryCircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Gauge(value: snapshot.todayProgress) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(snapshot.todayCompletedCount)/\(snapshot.todayTotalCount)")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(WidgetDeepLink.board)
    }
}

private struct AccessoryRectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(WidgetStrings.nextUp, systemImage: "sparkles")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
            if let title = snapshot.nextTaskTitle {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                    Text(String(format: WidgetStrings.progressFraction,
                                snapshot.todayCompletedCount, snapshot.todayTotalCount))
                        .monospacedDigit()
                }
                .font(.caption2)
            } else {
                Text(WidgetStrings.allCaughtUp)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetDeepLink.board)
    }
}

private struct AccessoryInlineView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let title = snapshot.nextTaskTitle {
            Label(title, systemImage: "checklist")
        } else {
            Label(WidgetStrings.allCaughtUp, systemImage: "checkmark.circle.fill")
        }
    }
}

private struct CountPill: View {
    let value: Int
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(value)")
                .monospacedDigit()
        }
        .font(.system(.caption2, design: .rounded).weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct StatRow: View {
    let symbol: String
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WP.secondaryText)
            Spacer()
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(WP.primaryText)
                .monospacedDigit()
        }
    }
}

// MARK: - Widget

struct HomeMateWidget: Widget {
    let kind = "HomeMateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomeMateProvider()) { entry in
            HomeMateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetStrings.displayName)
        .description(WidgetStrings.description)
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Localized strings

enum WidgetStrings {
    static let displayName = String(localized: "widget.displayName", defaultValue: "ふたりボード")
    static let description = String(localized: "widget.description", defaultValue: "次にやることと今日の残りをひと目で。")
    static let nextUp = String(localized: "widget.nextUp", defaultValue: "次にやること")
    static let allCaughtUp = String(localized: "widget.allCaughtUp", defaultValue: "ひと段落しています")
    static let today = String(localized: "widget.today", defaultValue: "今日")
    static let groceries = String(localized: "widget.groceries", defaultValue: "買い物")
    static let requests = String(localized: "widget.requests", defaultValue: "お願い")
    static let progressFraction = String(localized: "widget.progressFraction", defaultValue: "%lld / %lld 完了")
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        homeName: "わが家",
        nextTaskTitle: "ゴミ出し",
        nextTaskDueAt: Date().addingTimeInterval(3600),
        nextTaskAssigneeName: "あなた",
        todayTaskCount: 3,
        groceryCount: 5,
        requestCount: 1,
        todayCompletedCount: 2,
        todayTotalCount: 5,
        updatedAt: Date()
    )
}

#Preview(as: .systemSmall) {
    HomeMateWidget()
} timeline: {
    HomeMateEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    HomeMateWidget()
} timeline: {
    HomeMateEntry(date: .now, snapshot: .preview)
}

#Preview(as: .accessoryCircular) {
    HomeMateWidget()
} timeline: {
    HomeMateEntry(date: .now, snapshot: .preview)
}

#Preview(as: .accessoryRectangular) {
    HomeMateWidget()
} timeline: {
    HomeMateEntry(date: .now, snapshot: .preview)
}
