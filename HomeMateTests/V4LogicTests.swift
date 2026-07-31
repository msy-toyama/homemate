//
//  V4LogicTests.swift
//  HomeMateTests
//
//  V4（完了の安全性・取り消し・ロケール整形）のコアロジック単体テスト。
//

import Testing
import CoreData
import Foundation
@testable import HomeMate

struct V4LogicTests {

    @MainActor
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @MainActor
    private func makeHome(_ ctx: NSManagedObjectContext) throws -> Home {
        try HomeService(context: ctx)
            .createHome(name: "Test", homeType: .roommates, currentMemberName: "Me", locale: "ja")
    }

    @MainActor
    private func makeChore(_ ctx: NSManagedObjectContext, in home: Home, due: Date?) -> Task {
        let task = Task(context: ctx)
        task.id = UUID()
        task.title = "Chore"
        task.status = TaskStatus.active.rawValue
        task.taskTypeValue = .chore
        task.home = home
        task.dueAt = due
        return task
    }

    // MARK: - 未来時刻の完了ガード

    @Test @MainActor func canCompleteNowGuardsFutureDates() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let task = makeChore(ctx, in: home, due: nil)

        // 期限なしはいつでも完了できる。
        #expect(task.canCompleteNow() == true)

        // 翌日以降の未来タスクは false（確認を促す）。
        task.dueAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        #expect(task.canCompleteNow() == false)

        // 期限切れ・今日は true。
        task.dueAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(task.canCompleteNow() == true)
        task.dueAt = Date()
        #expect(task.canCompleteNow() == true)
    }

    // MARK: - 完了の取り消しと次回分の巻き戻し

    @Test @MainActor func reactivateRemovesGeneratedNextOccurrence() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let task = makeChore(ctx, in: home, due: Date())
        task.recurrenceRule = RecurrenceRule(frequency: .weekly, interval: 1, weekdays: [], dayOfMonth: 0)
        task.seriesId = UUID()
        try ctx.save()

        let service = TaskService(context: ctx)
        let result = try service.complete(task, by: home.currentMember)

        // 完了で次回分が自動生成される。
        #expect(result.generatedTask != nil)
        #expect(task.isCompleted)
        let activeAfterComplete = home.tasksArray.filter { $0.taskStatusValue == .active }
        #expect(activeAfterComplete.count == 1)

        // 取り消すと元タスクが復活し、生成された次回分は削除される。
        try service.reactivate(task, removingGenerated: result.generatedTask)
        #expect(!task.isCompleted)
        let activeAfterUndo = home.tasksArray.filter { $0.taskStatusValue == .active }
        #expect(activeAfterUndo.count == 1)
        #expect(activeAfterUndo.first?.objectID == task.objectID)
    }

    @Test @MainActor func generatedNextOccurrenceFindsSibling() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let task = makeChore(ctx, in: home, due: Date())
        task.recurrenceRule = RecurrenceRule(frequency: .daily, interval: 1, weekdays: [], dayOfMonth: 0)
        task.seriesId = UUID()
        try ctx.save()

        let service = TaskService(context: ctx)
        let result = try service.complete(task, by: home.currentMember)
        let found = service.generatedNextOccurrence(of: task)
        #expect(found?.objectID == result.generatedTask?.objectID)
    }

    // MARK: - 「完了したのに残る」防止：次回分は未来日付で重複しない

    @Test @MainActor func completingRecurringTaskLeavesSingleFutureOccurrence() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        // 期限が今日（当日）の毎日タスク。
        let task = makeChore(ctx, in: home, due: Calendar.current.startOfDay(for: Date()))
        task.recurrenceRule = RecurrenceRule(frequency: .daily, interval: 1, weekdays: [], dayOfMonth: 0)
        task.seriesId = UUID()
        try ctx.save()

        let service = TaskService(context: ctx)
        let result = try service.complete(task, by: home.currentMember)

        // 完了した元タスクはアクティブ一覧から外れている。
        #expect(task.isCompleted)
        let active = home.tasksArray.filter { $0.taskStatusValue == .active }
        #expect(active.count == 1)

        // 残るアクティブは生成された次回分のみで、期限は未来（今日より後）。
        let generated = try #require(result.generatedTask)
        #expect(active.first?.objectID == generated.objectID)
        let due = try #require(generated.dueAt)
        #expect(due > Date())
        #expect(!Calendar.current.isDateInToday(due))
    }

    // MARK: - ロケール対応の繰り返しサマリ

    @Test func recurrenceSummaryUsesLocaleForWeekdays() {
        // 月曜(2)・金曜(6)。
        let rule = RecurrenceRule(frequency: .weekly, interval: 1, weekdays: [2, 6], dayOfMonth: 0)
        let ja = rule.summary(locale: Locale(identifier: "ja"))
        let en = rule.summary(locale: Locale(identifier: "en"))
        // ロケールにより曜日名・区切りが変わるため一致しない。
        #expect(ja != en)
        #expect(ja.contains("月"))
        #expect(ja.contains("金"))
    }
}

// MARK: - V9 通知タイミング

struct V9NotificationTests {

    @MainActor
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @MainActor
    private func makeHome(_ ctx: NSManagedObjectContext) throws -> Home {
        try HomeService(context: ctx)
            .createHome(name: "Test", homeType: .roommates, currentMemberName: "Me", locale: "ja")
    }

    @MainActor
    private func makeChore(_ ctx: NSManagedObjectContext, in home: Home, due: Date?) -> Task {
        let task = Task(context: ctx)
        task.id = UUID()
        task.title = "Chore"
        task.status = TaskStatus.active.rawValue
        task.taskTypeValue = .chore
        task.home = home
        task.dueAt = due
        return task
    }

    // MARK: - NotificationLeadTime のマッピング

    @Test func leadTimeMinutesBeforeMapping() {
        #expect(NotificationLeadTime.off.minutesBefore == nil)
        #expect(NotificationLeadTime.atTime.minutesBefore == 0)
        #expect(NotificationLeadTime.min30.minutesBefore == 30)
        #expect(NotificationLeadTime.hour1.minutesBefore == 60)
        #expect(NotificationLeadTime.day1.minutesBefore == 1440)
        #expect(NotificationLeadTime.day3.minutesBefore == 4320)
    }

    @Test func leadTimeFromMinutesFallsBackToHour1() {
        #expect(NotificationLeadTime.from(minutes: 60) == .hour1)
        #expect(NotificationLeadTime.from(minutes: -1) == .off)
        // 未知の値は既定（1時間前）に丸める。
        #expect(NotificationLeadTime.from(minutes: 999) == .hour1)
    }

    // MARK: - notificationFireDate（通常タスク）

    @Test @MainActor func fireDateSubtractsOffsetForTimedTask() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        // 十分未来の固定期限。
        let due = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = makeChore(ctx, in: home, due: due)
        task.isAllDay = false
        task.notificationLeadTimeValue = .hour1

        let expected = Calendar.current.date(byAdding: .minute, value: -60, to: due)
        #expect(task.notificationFireDate == expected)
    }

    @Test @MainActor func fireDateAtTimeEqualsDue() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let due = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = makeChore(ctx, in: home, due: due)
        task.isAllDay = false
        task.notificationLeadTimeValue = .atTime
        #expect(task.notificationFireDate == due)
    }

    // MARK: - notificationFireDate（終日タスクは 9:00 基準）

    @Test @MainActor func fireDateForAllDayUsesNineAmAnchor() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let cal = Calendar.current
        let due = cal.date(byAdding: .day, value: 5, to: Date())!
        let task = makeChore(ctx, in: home, due: due)
        task.isAllDay = true
        task.notificationLeadTimeValue = .hour1

        let nineAm = cal.date(bySettingHour: 9, minute: 0, second: 0, of: due)!
        let expected = cal.date(byAdding: .minute, value: -60, to: nineAm)
        #expect(task.notificationFireDate == expected)
    }

    // MARK: - off / 期限なし / お願いは nil

    @Test @MainActor func fireDateNilWhenOff() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let due = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = makeChore(ctx, in: home, due: due)
        task.notificationLeadTimeValue = .off
        #expect(task.notificationFireDate == nil)
    }

    @Test @MainActor func fireDateNilWhenNoDueDate() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let task = makeChore(ctx, in: home, due: nil)
        task.notificationLeadTimeValue = .hour1
        #expect(task.notificationFireDate == nil)
    }

    @Test @MainActor func fireDateNilForRequest() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let due = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = makeChore(ctx, in: home, due: due)
        task.taskTypeValue = .request
        task.notificationLeadTimeValue = .hour1
        #expect(task.notificationFireDate == nil)
    }

    // MARK: - 永続化（オフセットの保存・既定値）

    @Test @MainActor func defaultOffsetIsOneHour() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let service = TaskService(context: ctx)
        let due = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = try service.create(in: home, title: "T", type: .chore,
                                      assignedTo: nil, dueAt: due, isAllDay: false,
                                      by: home.currentMember)
        #expect(task.notificationLeadTimeValue == .hour1)
    }
}

