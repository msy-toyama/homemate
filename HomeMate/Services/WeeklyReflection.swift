//
//  WeeklyReflection.swift
//  HomeMate
//
//  メンタルロード（見えない負担）の週次振り返り。相手を責めず・順位づけせず・
//  赤色を使わず、ふたりの頑張りをやさしく可視化する（設計 19・20章）。
//

import Foundation

/// メンバーごとの貢献内訳。
struct MemberContribution: Identifiable {
    let memberId: UUID
    let displayName: String
    let colorToken: ColorToken
    let noticeCount: Int
    let planCount: Int
    let doCount: Int
    let thanksReceived: Int

    var id: UUID { memberId }
    /// 見えない負担（気づき＋段取り）。
    var invisibleLoad: Int { noticeCount + planCount }
    var total: Int { noticeCount + planCount + doCount }
}

struct WeeklyReflection {
    let shouldShow: Bool
    let completedThisWeek: Int
    let thanksThisWeek: Int
    let contributions: [MemberContribution]

    static let empty = WeeklyReflection(shouldShow: false,
                                        completedThisWeek: 0,
                                        thanksThisWeek: 0,
                                        contributions: [])
}

enum WeeklyReflectionResolver {
    static func reflect(for home: Home,
                        now: Date = Date(),
                        calendar: Calendar = .current) -> WeeklyReflection {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let events = (home.mentalLoadEvents as? Set<MentalLoadEvent> ?? [])
            .filter { ($0.createdAt ?? .distantPast) >= weekAgo }

        let completedThisWeek = home.tasksArray.filter {
            $0.taskStatusValue == .completed && ($0.completedAt ?? .distantPast) >= weekAgo
        }.count
        let thanksThisWeek = events.filter { $0.eventTypeValue == .thanks }.count

        // メンバーごとに集計。
        var contributions: [MemberContribution] = []
        for member in home.membersArray {
            guard let mid = member.id else { continue }
            let mine = events.filter { $0.actorMemberId == mid }
            let thanksReceived = (home.thanksReactions as? Set<ThanksReaction> ?? [])
                .filter { $0.toMemberId == mid && ($0.createdAt ?? .distantPast) >= weekAgo }
                .count
            contributions.append(MemberContribution(
                memberId: mid,
                displayName: member.resolvedDisplayName,
                colorToken: member.colorTokenValue,
                noticeCount: mine.filter { $0.eventTypeValue == .notice }.count,
                planCount: mine.filter { $0.eventTypeValue == .plan }.count,
                doCount: mine.filter { $0.eventTypeValue == .do }.count,
                thanksReceived: thanksReceived
            ))
        }

        // 表示条件：作成から3日以上経過、または「完了3件以上 かつ イベント3件以上」。
        let homeAgeDays = calendar.dateComponents([.day],
                                                  from: home.createdAt ?? now,
                                                  to: now).day ?? 0
        let shouldShow = homeAgeDays >= 3 || (completedThisWeek >= 3 && events.count >= 3)

        return WeeklyReflection(shouldShow: shouldShow,
                                completedThisWeek: completedThisWeek,
                                thanksThisWeek: thanksThisWeek,
                                contributions: contributions)
    }
}
