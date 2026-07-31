//
//  RecurrenceRule.swift
//  HomeMate
//
//  タスクの繰り返しルールを表す値型と、次回日時を計算するエンジン。
//  スポット(none) / 毎日・N日ごと / 毎週(複数曜日)・N週ごと / 毎月X日・Nヶ月ごと に対応する。
//

import Foundation

// MARK: - RecurrenceRule

/// 繰り返しルール。Core Data の Task の各属性（repeatFrequency / repeatInterval /
/// repeatWeekdays / repeatDayOfMonth）と相互変換して使う。
struct RecurrenceRule: Equatable {
    /// 繰り返しの種類。
    var frequency: RepeatFrequency
    /// 間隔（1 以上）。例: weekly で 2 なら「2週間ごと」。
    var interval: Int
    /// 毎週指定時の曜日集合（Calendar 準拠で 1=日曜 … 7=土曜）。空なら基準日の曜日。
    var weekdays: Set<Int>
    /// 毎月指定時の日（1〜31）。0 なら基準日の「日」を使う。
    var dayOfMonth: Int

    init(frequency: RepeatFrequency = .none,
         interval: Int = 1,
         weekdays: Set<Int> = [],
         dayOfMonth: Int = 0) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.dayOfMonth = dayOfMonth
    }

    static let none = RecurrenceRule(frequency: .none)

    var isRepeating: Bool { frequency != .none }
}

// MARK: - 人間可読サマリ

extension RecurrenceRule {
    /// 「毎週 火・金」「2週間ごと」「毎月15日」のような表示用文字列を返す。
    func summary(locale: Locale = .current) -> String {
        switch frequency {
        case .none:
            return LanguageManager.localized("recurrence.none")
        case .daily:
            return interval == 1
                ? LanguageManager.localized("recurrence.daily")
                : LanguageManager.localized("recurrence.everyNDays", interval)
        case .weekly:
            let base = interval == 1
                ? LanguageManager.localized("recurrence.weekly")
                : LanguageManager.localized("recurrence.everyNWeeks", interval)
            guard !weekdays.isEmpty else { return base }
            let names = Self.weekdayShortNames(for: weekdays, locale: locale)
            let separator = (locale.language.languageCode?.identifier == "ja") ? "・" : ", "
            return base + " " + names.joined(separator: separator)
        case .monthly:
            if dayOfMonth > 0 {
                return LanguageManager.localized("recurrence.monthlyOnDay", dayOfMonth)
            }
            return interval == 1
                ? LanguageManager.localized("recurrence.monthly")
                : LanguageManager.localized("recurrence.everyNMonths", interval)
        }
    }

    /// 曜日集合を、ロケールに合わせた短い曜日名（日曜→土曜の順）に変換する。
    static func weekdayShortNames(for weekdays: Set<Int>, locale: Locale) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.shortWeekdaySymbols // 0=日 … 6=土
        return weekdays.sorted().compactMap { weekday in
            let index = weekday - 1
            guard index >= 0, index < symbols.count else { return nil }
            return symbols[index]
        }
    }
}

// MARK: - 次回日時の計算エンジン

enum RecurrenceEngine {
    /// 基準日時 `base`（前回の期限）から、`now` を超える次回の期限日時を計算する。
    /// 時刻（時・分・秒）は base のものを保持する。none の場合は nil。
    static func nextDate(after base: Date,
                         rule: RecurrenceRule,
                         now: Date,
                         calendar: Calendar = .current) -> Date? {
        let interval = max(1, rule.interval)
        switch rule.frequency {
        case .none:
            return nil
        case .daily:
            return advanceByDays(base: base, days: interval, now: now, calendar: calendar)
        case .weekly:
            return nextWeekly(base: base, interval: interval, weekdays: rule.weekdays,
                              now: now, calendar: calendar)
        case .monthly:
            return nextMonthly(base: base, interval: interval, dayOfMonth: rule.dayOfMonth,
                               now: now, calendar: calendar)
        }
    }

    // MARK: 日次・週次（曜日指定なし）

    private static func advanceByDays(base: Date, days: Int, now: Date, calendar: Calendar) -> Date? {
        var candidate = base
        var safety = 0
        repeat {
            guard let advanced = calendar.date(byAdding: .day, value: days, to: candidate),
                  advanced > candidate else { return nil }
            candidate = advanced
            safety += 1
            if safety > 10000 { break }
        } while candidate <= now
        return candidate
    }

    // MARK: 週次（曜日指定あり / N週ごと）

    private static func nextWeekly(base: Date, interval: Int, weekdays: Set<Int>,
                                   now: Date, calendar: Calendar) -> Date? {
        // 曜日指定なし: 基準日の曜日のまま interval 週ずつ進める。
        guard !weekdays.isEmpty else {
            var candidate = base
            var safety = 0
            repeat {
                guard let advanced = calendar.date(byAdding: .day, value: 7 * interval, to: candidate),
                      advanced > candidate else { return nil }
                candidate = advanced
                safety += 1
                if safety > 10000 { break }
            } while candidate <= now
            return candidate
        }

        guard let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: base)?.start else { return nil }
        let time = calendar.dateComponents([.hour, .minute, .second], from: base)
        var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: base)) ?? base
        var safety = 0
        while safety < 4000 {
            safety += 1
            let weekday = calendar.component(.weekday, from: day)
            if weekdays.contains(weekday),
               let dayWeek = calendar.dateInterval(of: .weekOfYear, for: day)?.start {
                let weeks = calendar.dateComponents([.weekOfYear], from: anchorWeek, to: dayWeek).weekOfYear ?? 0
                if weeks % interval == 0,
                   let candidate = calendar.date(bySettingHour: time.hour ?? 0,
                                                 minute: time.minute ?? 0,
                                                 second: time.second ?? 0,
                                                 of: day),
                   candidate > now {
                    return candidate
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = nextDay
        }
        return nil
    }

    // MARK: 月次（毎月X日 / Nヶ月ごと・月末クランプ）

    private static func nextMonthly(base: Date, interval: Int, dayOfMonth: Int,
                                    now: Date, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second], from: base)
        let targetDay = dayOfMonth > 0 ? dayOfMonth : calendar.component(.day, from: base)
        var step = 1
        while step < 10000 {
            guard let monthDate = calendar.date(byAdding: .month, value: interval * step, to: base) else { return nil }
            if let candidate = dateBySettingClampedDay(targetDay, time: time, in: monthDate, calendar: calendar),
               candidate > now {
                return candidate
            }
            step += 1
        }
        return nil
    }

    /// 指定した「日」を、その月の日数でクランプしてセットした日時を返す（例: 2月の31日→28/29日）。
    private static func dateBySettingClampedDay(_ day: Int, time: DateComponents,
                                                in monthDate: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: monthDate)
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? Range(1...28)
        let maxDay = range.upperBound - 1
        comps.day = min(max(1, day), maxDay)
        comps.hour = time.hour ?? 0
        comps.minute = time.minute ?? 0
        comps.second = time.second ?? 0
        return calendar.date(from: comps)
    }
}
