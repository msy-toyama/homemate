//
//  DomainEnums.swift
//  HomeMate
//
//  ドメインで使う文字列バック enum。Core Data の String 属性と相互変換する。
//

import Foundation
import SwiftUI

// MARK: - Home

enum HomeType: String, CaseIterable, Identifiable {
    case couple
    case roommates
    case family
    case solo

    var id: String { rawValue }

    /// オンボーディングの「誰と使うか」選択肢に対応する。
    var onboardingTitleKey: LocalizedStringKey {
        switch self {
        case .couple: return "onboarding.audience.partner"
        case .roommates: return "onboarding.audience.roommates"
        case .family: return "onboarding.audience.family"
        case .solo: return "onboarding.audience.solo"
        }
    }

    /// 選択肢に添えるアイコン。
    var onboardingSymbol: String {
        switch self {
        case .couple: return "heart.fill"
        case .roommates: return "person.2.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .solo: return "person.fill"
        }
    }
}

// MARK: - Member

enum MemberRole: String, CaseIterable {
    case owner
    case member
}

// MARK: - Task

enum TaskType: String, CaseIterable, Identifiable {
    case chore
    case request

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .chore: return "house.fill"
        case .request: return "hand.raised.fill"
        }
    }
}

enum TaskStatus: String, CaseIterable {
    case active
    case completed
    case archived
    case paused
}

enum RotationPolicy: String, CaseIterable, Identifiable {
    case fixed
    case alternate
    case anyone

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .fixed: return "rotation.fixed"
        case .alternate: return "rotation.alternate"
        case .anyone: return "rotation.anyone"
        }
    }
}

enum EffortLevel: Int16, CaseIterable, Identifiable {
    case light = 1
    case normal = 2
    case heavy = 3

    var id: Int16 { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .light: return "effort.light"
        case .normal: return "effort.normal"
        case .heavy: return "effort.heavy"
        }
    }
}

enum RepeatFrequency: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .none: return "repeat.none"
        case .daily: return "repeat.daily"
        case .weekly: return "repeat.weekly"
        case .monthly: return "repeat.monthly"
        }
    }
}

/// タスクのスケジュール通知をいつ出すか（期限のどれだけ前か）。
/// `rawValue` は「期限の何分前か」を表す分数。`off` だけは負のセンチネル。
/// 終日タスクでは当日 9:00 を基準にこのオフセットを適用する。
enum NotificationLeadTime: Int16, CaseIterable, Identifiable {
    case off = -1
    case atTime = 0
    case min5 = 5
    case min15 = 15
    case min30 = 30
    case hour1 = 60
    case hour3 = 180
    case day1 = 1440
    case day3 = 4320

    var id: Int16 { rawValue }

    /// 期限の何分前か。`off` は通知しないため nil。
    var minutesBefore: Int? {
        self == .off ? nil : Int(rawValue)
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .off: return "schedule.notify.off"
        case .atTime: return "schedule.notify.atTime"
        case .min5: return "schedule.notify.min5"
        case .min15: return "schedule.notify.min15"
        case .min30: return "schedule.notify.min30"
        case .hour1: return "schedule.notify.hour1"
        case .hour3: return "schedule.notify.hour3"
        case .day1: return "schedule.notify.day1"
        case .day3: return "schedule.notify.day3"
        }
    }

    /// 保存値（分）から最も近い選択肢を得る。未知の値は既定（1時間前）に丸める。
    static func from(minutes: Int16) -> NotificationLeadTime {
        NotificationLeadTime(rawValue: minutes) ?? .hour1
    }
}

/// タスクの公開範囲。private は作成者本人の端末にのみ表示する（app 層のフィルタ）。
enum TaskVisibility: String, CaseIterable, Identifiable {
    case shared
    case `private`

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .shared: return "visibility.shared"
        case .private: return "visibility.private"
        }
    }

    var symbolName: String {
        switch self {
        case .shared: return "person.2.fill"
        case .private: return "lock.fill"
        }
    }
}

// MARK: - Request (Task の taskType == request の状態)

/// お願いの状態。設計上「拒否」表現は禁止し「今は難しい」を使う。
enum RequestStatus: String, CaseIterable, Identifiable {
    case pending
    case accepted
    case done
    case notNow

    var id: String { rawValue }

    /// Core Data の Task.status へマッピングする。
    var taskStatus: TaskStatus {
        switch self {
        case .pending, .accepted, .notNow: return .active
        case .done: return .completed
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .pending: return "request.status.pending"
        case .accepted: return "request.status.accepted"
        case .done: return "request.status.done"
        case .notNow: return "request.status.notNow"
        }
    }
}

// MARK: - Grocery

enum GroceryStatus: String, CaseIterable {
    case active
    case completed
    case archived
}

enum GroceryCategory: String, CaseIterable, Identifiable {
    case food
    case household
    case cleaning
    case drinks
    case other

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .food: return "grocery.category.food"
        case .household: return "grocery.category.household"
        case .cleaning: return "grocery.category.cleaning"
        case .drinks: return "grocery.category.drinks"
        case .other: return "grocery.category.other"
        }
    }
}

// MARK: - MentalLoad

enum MentalLoadEventType: String, CaseIterable {
    case notice
    case plan
    case `do`
    case thanks
}

enum MentalLoadTargetType: String {
    case task
    case grocery
    case request
}

// MARK: - Thanks

enum ReactionType: String, CaseIterable, Identifiable {
    case thanks
    case helpful
    case nice
    case amazing

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .thanks: return "🙏"
        case .helpful: return "✨"
        case .nice: return "👍"
        case .amazing: return "🎉"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .thanks: return "thanks.thanks"
        case .helpful: return "thanks.helpful"
        case .nice: return "thanks.nice"
        case .amazing: return "thanks.amazing"
        }
    }
}

// MARK: - Color tokens

/// メンバーの担当色などに使うやさしいカラートークン。
enum ColorToken: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple
    case pink
    case teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.30, green: 0.56, blue: 0.92)
        case .green: return Color(red: 0.30, green: 0.72, blue: 0.52)
        case .orange: return Color(red: 0.96, green: 0.62, blue: 0.30)
        case .purple: return Color(red: 0.58, green: 0.50, blue: 0.86)
        case .pink: return Color(red: 0.92, green: 0.52, blue: 0.66)
        case .teal: return Color(red: 0.30, green: 0.70, blue: 0.74)
        }
    }
}
