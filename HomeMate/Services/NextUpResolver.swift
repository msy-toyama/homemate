//
//  NextUpResolver.swift
//  HomeMate
//
//  「次にやること」を1件決める優先順位ロジック（設計 13.5）。
//  1. 期限切れ → 2. 今日が期限 → 3. 自分が担当 → 4. お願いされたタスク
//  → 5. 繰り返しタスク → 6. 作成日時が新しいタスク
//

import Foundation

enum NextUpResolver {
    /// 「次にやること」スロットに表示する対象。タスク1件か、未完了の買い物まとめ。
    enum Item {
        case task(Task)
        case groceries([GroceryItem])
    }

    /// タスクと買い物を合わせて「次にやること」を1スロット決める。
    /// 優先順位: ①期限切れ ②今日が期限 ③未完了の買い物 ④それ以外のタスク（担当/お願い/繰り返し/その他）。
    static func resolveItem(tasks: [Task],
                            groceries: [GroceryItem],
                            currentMemberId: UUID?,
                            now: Date = Date(),
                            calendar: Calendar = .current) -> Item? {
        let activeGroceries = groceries.filter { $0.statusValue == .active }
        let bestTask = resolve(from: tasks, currentMemberId: currentMemberId, now: now, calendar: calendar)
        if let bestTask {
            let rank = priorityRank(for: bestTask, currentMemberId: currentMemberId, now: now, calendar: calendar)
            // 期限切れ・今日が期限のタスクは買い物より優先。
            if rank <= 2 { return .task(bestTask) }
        }
        if !activeGroceries.isEmpty { return .groceries(activeGroceries) }
        if let bestTask { return .task(bestTask) }
        return nil
    }

    static func resolve(from tasks: [Task],
                        currentMemberId: UUID?,
                        now: Date = Date(),
                        calendar: Calendar = .current) -> Task? {
        let candidates = tasks.filter { $0.taskStatusValue == .active }
        return candidates.min { lhs, rhs in
            let l = sortKey(for: lhs, currentMemberId: currentMemberId, now: now, calendar: calendar)
            let r = sortKey(for: rhs, currentMemberId: currentMemberId, now: now, calendar: calendar)
            return l < r
        }
    }

    /// 優先度ランク（小さいほど重要）。
    static func priorityRank(for task: Task,
                             currentMemberId: UUID?,
                             now: Date,
                             calendar: Calendar) -> Int {
        if let due = task.dueAt, due < now { return 1 }
        if let due = task.dueAt, calendar.isDate(due, inSameDayAs: now) { return 2 }
        if let assignee = task.assignedToMemberId, assignee == currentMemberId { return 3 }
        if task.taskTypeValue == .request, task.assignedToMemberId == currentMemberId { return 4 }
        if task.repeatFrequencyValue != RepeatFrequency.none { return 5 }
        return 6
    }

    private static func sortKey(for task: Task,
                                currentMemberId: UUID?,
                                now: Date,
                                calendar: Calendar) -> SortKey {
        SortKey(
            rank: priorityRank(for: task, currentMemberId: currentMemberId, now: now, calendar: calendar),
            due: task.dueAt ?? .distantFuture,
            createdAt: task.createdAt ?? .distantPast
        )
    }

    private struct SortKey: Comparable {
        let rank: Int
        let due: Date
        let createdAt: Date

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.due != rhs.due { return lhs.due < rhs.due }
            // 同条件なら新しい作成日時を優先（降順）。
            return lhs.createdAt > rhs.createdAt
        }
    }
}
