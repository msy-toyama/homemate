//
//  WidgetCacheService.swift
//  HomeMate
//
//  ホームの状態を集計し、Core Data の WidgetCache と App Group スナップショットを更新する。
//  WidgetKit のタイムラインも再読み込みさせる。
//

import CoreData
import WidgetKit

struct WidgetCacheService {
    let context: NSManagedObjectContext

    /// ホームの現在状態から Widget 用キャッシュ／スナップショットを更新する。
    func refresh(for home: Home, now: Date = Date(), calendar: Calendar = .current) {
        let meId = home.currentMember?.id
        // この端末のユーザー視点で見えるタスクのみ集計する（他メンバーの非公開タスクは除外）。
        let visibleTasks = home.tasksArray.filter { task in
            task.visibilityValue == .shared || task.createdByMemberId == meId
        }
        let activeTasks = visibleTasks.filter { $0.taskStatusValue == .active }

        // 今日の家事：request を除く、期限なし/今日/期限切れのアクティブタスク。
        let todayTasks = activeTasks.filter { task in
            guard task.taskTypeValue != .request else { return false }
            guard let due = task.dueAt else { return true }
            return due <= now || calendar.isDate(due, inSameDayAs: now)
        }
        // 今日完了した家事（進捗リングの分子）。
        let todayCompleted = visibleTasks.filter { task in
            guard task.taskTypeValue != .request, task.taskStatusValue == .completed,
                  let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: now)
        }
        let todayTotal = todayTasks.count + todayCompleted.count
        let groceryCount = home.groceriesArray.filter { $0.statusValue == .active }.count
        let requestCount = activeTasks.filter { $0.taskTypeValue == .request }.count

        let nextTask = NextUpResolver.resolve(from: activeTasks,
                                              currentMemberId: home.currentMember?.id,
                                              now: now,
                                              calendar: calendar)
        let assigneeName = home.member(withID: nextTask?.assignedToMemberId)?.resolvedDisplayName

        // Core Data の WidgetCache を1件にまとめて upsert する。
        let cache = (home.widgetCaches as? Set<WidgetCache>)?.first ?? {
            let c = WidgetCache(context: context)
            c.id = UUID()
            c.home = home
            return c
        }()
        cache.homeName = home.displayName
        cache.nextTaskTitle = nextTask?.resolvedTitle
        cache.nextTaskDueAt = nextTask?.dueAt
        cache.nextTaskAssigneeName = assigneeName
        cache.todayTaskCount = Int16(todayTasks.count)
        cache.groceryCount = Int16(groceryCount)
        cache.requestCount = Int16(requestCount)
        cache.updatedAt = now

        // App Group スナップショットを書き出す。
        let snapshot = WidgetSnapshot(
            homeName: home.displayName,
            nextTaskTitle: nextTask?.resolvedTitle,
            nextTaskDueAt: nextTask?.dueAt,
            nextTaskAssigneeName: assigneeName,
            todayTaskCount: todayTasks.count,
            groceryCount: groceryCount,
            requestCount: requestCount,
            todayCompletedCount: todayCompleted.count,
            todayTotalCount: todayTotal,
            updatedAt: now
        )
        snapshot.save()

        WidgetCenter.shared.reloadAllTimelines()
    }
}
