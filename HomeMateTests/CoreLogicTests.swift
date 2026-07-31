//
//  CoreLogicTests.swift
//  HomeMateTests
//
//  Phase 3 のコアロジック（次にやること・繰り返し期限・担当交代）の単体テスト。
//

import Testing
import CoreData
@testable import HomeMate

struct CoreLogicTests {

    @MainActor
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    // MARK: - nextDueDate

    @Test func nextDueDateNoneReturnsNil() {
        #expect(TaskService.nextDueDate(from: Date(), frequency: .none, now: Date()) == nil)
    }

    @Test func nextDueDateAdvancesBeyondNow() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let base = cal.date(byAdding: .day, value: -10, to: now)!
        let next = TaskService.nextDueDate(from: base, frequency: .daily, now: now, calendar: cal)
        #expect(next != nil)
        #expect((next ?? .distantPast) > now)
    }

    @Test func nextDueDateWeeklyIsSevenDaysFromFutureBase() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let base = cal.date(byAdding: .day, value: 1, to: now)!
        let next = TaskService.nextDueDate(from: base, frequency: .weekly, now: now, calendar: cal)
        let expected = cal.date(byAdding: .weekOfYear, value: 1, to: base)
        #expect(next == expected)
    }

    @Test func nextDueDateTerminatesForFarPastBase() {
        // 遠い過去を起点にしても無限ループにならず、now を超える日付を返す。
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let base = cal.date(byAdding: .year, value: -5, to: now)!
        let next = TaskService.nextDueDate(from: base, frequency: .daily, now: now, calendar: cal)
        #expect(next != nil)
        #expect((next ?? .distantPast) > now)
    }

    // MARK: - RecurrenceEngine

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0,
                          calendar cal: Calendar = Calendar(identifier: .gregorian)) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return cal.date(from: comps)!
    }

    @Test func recurrenceEveryThreeDaysAdvancesByInterval() {
        let cal = Calendar(identifier: .gregorian)
        let base = makeDate(2025, 1, 1)
        let rule = RecurrenceRule(frequency: .daily, interval: 3)
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: base, calendar: cal)
        #expect(next == makeDate(2025, 1, 4))
        // 時刻が保持される。
        #expect(cal.component(.hour, from: next!) == 9)
    }

    @Test func recurrenceWeeklyPicksNextMatchingWeekday() {
        let cal = Calendar(identifier: .gregorian)
        // 2025-01-01 は水曜日(weekday=4)。月(2)・木(5)を指定。
        let base = makeDate(2025, 1, 1)
        let rule = RecurrenceRule(frequency: .weekly, interval: 1, weekdays: [2, 5])
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: base, calendar: cal)
        // 次の該当は木曜 2025-01-02。
        #expect(next == makeDate(2025, 1, 2))
        #expect(cal.component(.weekday, from: next!) == 5)
    }

    @Test func recurrenceEveryTwoWeeksRespectsInterval() {
        let cal = Calendar(identifier: .gregorian)
        // 水曜起点、隔週の水曜。
        let base = makeDate(2025, 1, 1)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [4])
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: base, calendar: cal)
        // 翌週(1/8)はスキップされ、2週間後(1/15)になる。
        #expect(next == makeDate(2025, 1, 15))
    }

    @Test func recurrenceMonthlyAdvancesByMonths() {
        let cal = Calendar(identifier: .gregorian)
        let base = makeDate(2025, 1, 15)
        let rule = RecurrenceRule(frequency: .monthly, interval: 2)
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: base, calendar: cal)
        #expect(next == makeDate(2025, 3, 15))
    }

    @Test func recurrenceMonthlyClampsToMonthEnd() {
        let cal = Calendar(identifier: .gregorian)
        // 1/31 起点で毎月 → 2月は28日に丸められる(2025は平年)。
        let base = makeDate(2025, 1, 31)
        let rule = RecurrenceRule(frequency: .monthly, interval: 1)
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: base, calendar: cal)
        #expect(cal.component(.month, from: next!) == 2)
        #expect(cal.component(.day, from: next!) == 28)
    }

    @Test func recurrenceAlwaysAdvancesBeyondNow() {
        let cal = Calendar(identifier: .gregorian)
        let base = makeDate(2020, 1, 1)
        let now = makeDate(2025, 6, 15)
        let rule = RecurrenceRule(frequency: .daily, interval: 5)
        let next = RecurrenceEngine.nextDate(after: base, rule: rule, now: now, calendar: cal)
        #expect((next ?? .distantPast) > now)
    }

    // MARK: - RotationResolver

    @Test @MainActor func rotationAlternatesBetweenTwoMembers() {
        let ctx = makeContext()
        let m1 = Member(context: ctx); m1.id = UUID()
        let m2 = Member(context: ctx); m2.id = UUID()
        let members = [m1, m2]
        #expect(RotationResolver.nextAssignee(after: m1.id, members: members) == m2.id)
        #expect(RotationResolver.nextAssignee(after: m2.id, members: members) == m1.id)
    }

    @Test @MainActor func rotationWithNoCurrentReturnsFirst() {
        let ctx = makeContext()
        let m1 = Member(context: ctx); m1.id = UUID()
        let m2 = Member(context: ctx); m2.id = UUID()
        #expect(RotationResolver.nextAssignee(after: nil, members: [m1, m2]) == m1.id)
    }

    @Test func rotationWithEmptyMembersReturnsNil() {
        #expect(RotationResolver.nextAssignee(after: UUID(), members: []) == nil)
    }

    // MARK: - NextUpResolver

    @MainActor
    private func makeChore(in ctx: NSManagedObjectContext,
                          home: Home,
                          dueOffset: TimeInterval? = nil,
                          assignee: UUID? = nil,
                          repeating: Bool = false,
                          createdOffset: TimeInterval = 0) -> Task {
        let task = Task(context: ctx)
        task.id = UUID()
        task.taskTypeValue = .chore
        task.status = TaskStatus.active.rawValue
        task.home = home
        task.createdAt = Date().addingTimeInterval(createdOffset)
        if let dueOffset { task.dueAt = Date().addingTimeInterval(dueOffset) }
        task.assignedToMemberId = assignee
        if repeating { task.repeatFrequencyValue = .daily }
        return task
    }

    @Test @MainActor func nextUpPrefersOverdueOverFuture() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        let me = UUID()
        let overdue = makeChore(in: ctx, home: home, dueOffset: -3600)
        let future = makeChore(in: ctx, home: home, dueOffset: 86400 * 3)
        let result = NextUpResolver.resolve(from: [future, overdue], currentMemberId: me)
        #expect(result?.objectID == overdue.objectID)
    }

    @Test @MainActor func nextUpPrefersAssignedToMeOverUnassigned() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        let me = UUID()
        let mine = makeChore(in: ctx, home: home, assignee: me)
        let other = makeChore(in: ctx, home: home)
        let result = NextUpResolver.resolve(from: [other, mine], currentMemberId: me)
        #expect(result?.objectID == mine.objectID)
    }

    @Test @MainActor func nextUpIgnoresCompletedTasks() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        let me = UUID()
        let done = makeChore(in: ctx, home: home, dueOffset: -3600)
        done.status = TaskStatus.completed.rawValue
        let active = makeChore(in: ctx, home: home, dueOffset: 86400)
        let result = NextUpResolver.resolve(from: [done, active], currentMemberId: me)
        #expect(result?.objectID == active.objectID)
    }

    // MARK: - WeeklyReflection

    @Test @MainActor func reflectionShowsAfterThreeDays() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        home.createdAt = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        let reflection = WeeklyReflectionResolver.reflect(for: home)
        #expect(reflection.shouldShow)
    }

    @Test @MainActor func reflectionHiddenWhenNewAndEmpty() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        home.createdAt = Date()
        let reflection = WeeklyReflectionResolver.reflect(for: home)
        #expect(!reflection.shouldShow)
    }

    @Test @MainActor func reflectionCountsContributionsPerMember() {
        let ctx = makeContext()
        let home = Home(context: ctx); home.id = UUID()
        home.createdAt = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        let member = Member(context: ctx)
        member.id = UUID(); member.displayName = "A"; member.joinedAt = Date(); member.home = home

        let service = MentalLoadService(context: ctx)
        service.record(in: home, actorMemberId: member.id, targetType: .task, targetId: UUID(), eventType: .notice)
        service.record(in: home, actorMemberId: member.id, targetType: .task, targetId: UUID(), eventType: .plan)
        service.record(in: home, actorMemberId: member.id, targetType: .task, targetId: UUID(), eventType: .do)

        let reflection = WeeklyReflectionResolver.reflect(for: home)
        let contribution = reflection.contributions.first { $0.memberId == member.id }
        #expect(contribution?.noticeCount == 1)
        #expect(contribution?.planCount == 1)
        #expect(contribution?.doCount == 1)
        #expect(contribution?.total == 3)
    }
}
