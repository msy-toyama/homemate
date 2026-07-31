//
//  WidgetSnapshot.swift
//  HomeMate
//
//  Widget 表示用の軽量スナップショット。App Group 経由でアプリ本体から渡す。
//  Widget は Core Data 本体を複雑に読まず、このスナップショットだけを読む（設計 21.5）。
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var homeName: String
    var nextTaskTitle: String?
    var nextTaskDueAt: Date?
    var nextTaskAssigneeName: String?
    var todayTaskCount: Int
    var groceryCount: Int
    var requestCount: Int
    /// 今日のタスクのうち完了済みの件数。
    var todayCompletedCount: Int
    /// 今日のタスクの総数（完了＋残り）。進捗リングの分母。
    var todayTotalCount: Int
    var updatedAt: Date

    /// 今日の進捗率（0.0〜1.0）。総数 0 のときは 1.0（やることなし＝完了扱い）。
    var todayProgress: Double {
        guard todayTotalCount > 0 else { return 1.0 }
        return min(1.0, Double(todayCompletedCount) / Double(todayTotalCount))
    }

    static let empty = WidgetSnapshot(
        homeName: "",
        nextTaskTitle: nil,
        nextTaskDueAt: nil,
        nextTaskAssigneeName: nil,
        todayTaskCount: 0,
        groceryCount: 0,
        requestCount: 0,
        todayCompletedCount: 0,
        todayTotalCount: 0,
        updatedAt: .distantPast
    )
}

extension WidgetSnapshot {
    static let userDefaultsKey = "widgetSnapshot"

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: AppConfig.appGroupIdentifier)
    }

    /// App Group の UserDefaults から読み込む。
    static func load() -> WidgetSnapshot {
        guard let defaults = sharedDefaults(),
              let data = defaults.data(forKey: userDefaultsKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    /// App Group の UserDefaults に書き込む。
    func save() {
        guard let defaults = WidgetSnapshot.sharedDefaults(),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: WidgetSnapshot.userDefaultsKey)
    }
}
