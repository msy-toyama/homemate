//
//  TaskService.swift
//  HomeMate
//
//  家事・リマインダー（および request の一部）の作成と完了処理。
//  完了時は設計 16.3 の7ステップを実行する。
//

import CoreData

struct TaskService {
    let context: NSManagedObjectContext

    private var mentalLoad: MentalLoadService { MentalLoadService(context: context) }
    private var widgetCache: WidgetCacheService { WidgetCacheService(context: context) }

    struct CompletionResult {
        let completedTask: Task
        let generatedTask: Task?
    }

    // MARK: - Create

    @discardableResult
    func create(in home: Home,
                title: String,
                type: TaskType = .chore,
                assignedTo: Member? = nil,
                dueAt: Date? = nil,
                isAllDay: Bool = false,
                recurrence: RecurrenceRule = .none,
                rotation: RotationPolicy = .fixed,
                effort: EffortLevel = .normal,
                visibility: TaskVisibility = .shared,
                notificationOffsetMinutes: Int16 = NotificationLeadTime.hour1.rawValue,
                notes: String? = nil,
                by member: Member?) throws -> Task {
        let now = Date()
        let task = Task(context: context)
        task.id = UUID()
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskTypeValue = type
        task.assignedToMemberId = assignedTo?.id
        task.createdByMemberId = member?.id
        task.dueAt = dueAt
        task.isAllDay = dueAt != nil ? isAllDay : false
        task.recurrenceRule = recurrence
        task.rotationPolicyValue = rotation
        task.effortLevelValue = effort
        task.visibilityValue = visibility
        task.notificationOffsetMinutes = notificationOffsetMinutes
        task.notes = notes
        task.createdAt = now
        task.updatedAt = now
        task.home = home
        // 繰り返しタスクは系列 ID を付与し、「これ以降すべて削除」を可能にする。
        task.seriesId = recurrence.isRepeating ? UUID() : nil

        if type == .request {
            task.requestStatusValue = .pending
        } else {
            task.status = TaskStatus.active.rawValue
        }

        // メンタルロード：気づいて追加した（notice）。
        mentalLoad.record(in: home, actorMemberId: member?.id,
                          targetType: type == .request ? .request : .task,
                          targetId: task.id, eventType: .notice)
        // 計画（plan）：期限・担当・繰り返しのいずれかを設定した。
        if dueAt != nil || assignedTo != nil || recurrence.isRepeating {
            mentalLoad.record(in: home, actorMemberId: member?.id,
                              targetType: type == .request ? .request : .task,
                              targetId: task.id, eventType: .plan)
        }

        try context.save()
        widgetCache.refresh(for: home)
        try context.save()

        // やさしいリマインダーを予約（期限がある通常タスクのみ）。
        if type != .request, let id = task.id {
            NotificationService.shared.scheduleReminder(taskId: id, title: task.resolvedTitle, fireAt: task.notificationFireDate)
        }
        return task
    }

    // MARK: - Update

    /// 既存タスクの内容を更新する。スケジュール（期限・繰り返し）や公開範囲も変更できる。
    func update(_ task: Task,
                title: String,
                assignedTo: Member?,
                dueAt: Date?,
                isAllDay: Bool = false,
                recurrence: RecurrenceRule,
                rotation: RotationPolicy,
                effort: EffortLevel,
                visibility: TaskVisibility,
                notificationOffsetMinutes: Int16,
                notes: String?) throws {
        let home = task.home
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.assignedToMemberId = assignedTo?.id
        task.dueAt = dueAt
        task.isAllDay = dueAt != nil ? isAllDay : false
        task.recurrenceRule = recurrence
        task.rotationPolicyValue = rotation
        task.effortLevelValue = effort
        task.visibilityValue = visibility
        task.notificationOffsetMinutes = notificationOffsetMinutes
        task.notes = notes
        task.updatedAt = Date()
        // 繰り返しになった場合は系列 ID を付与、単発化したら系列 ID を外す。
        if recurrence.isRepeating, task.seriesId == nil {
            task.seriesId = UUID()
        } else if !recurrence.isRepeating {
            task.seriesId = nil
        }

        try context.save()
        if let home {
            widgetCache.refresh(for: home)
            try context.save()
        }

        if task.taskTypeValue != .request, let id = task.id {
            NotificationService.shared.cancelReminder(taskId: id)
            NotificationService.shared.scheduleReminder(taskId: id, title: task.resolvedTitle, fireAt: task.notificationFireDate)
        }
    }

    // MARK: - Complete

    @discardableResult
    func complete(_ task: Task, by member: Member?, now: Date = Date()) throws -> CompletionResult {
        // home が一時的に nil（CloudKit 同期中など）でも、タスク自体の完了は必ず反映する。
        // home 依存の副作用（メンタルロード記録・繰り返し生成・Widget 更新）は home がある場合のみ行う。
        let home = task.home

        // 1〜3. 完了状態・完了者・完了日時。
        if task.taskTypeValue == .request {
            task.requestStatusValue = .done
        } else {
            task.status = TaskStatus.completed.rawValue
        }
        task.completedByMemberId = member?.id
        task.completedAt = now
        task.updatedAt = now

        // 4. メンタルロード：実行（do）。
        if let home {
            mentalLoad.record(in: home, actorMemberId: member?.id,
                              targetType: task.taskTypeValue == .request ? .request : .task,
                              targetId: task.id, eventType: .do)
        }

        // 5・6. 繰り返しタスクの次回生成と交代制の担当切替。
        var generated: Task?
        if let home, task.taskTypeValue != .request, task.repeatFrequencyValue != .none {
            generated = makeNextOccurrence(of: task, in: home, now: now)
        }

        try context.save()
        // 7. Widget 更新。
        if let home {
            widgetCache.refresh(for: home)
            try context.save()
        }

        // 完了したタスクの予約済みリマインダーを取り消す。
        if let id = task.id {
            NotificationService.shared.cancelReminder(taskId: id)
        }
        // 繰り返しで生成された次回分にリマインダーを予約。
        if let generated, let id = generated.id {
            NotificationService.shared.scheduleReminder(taskId: id, title: generated.resolvedTitle, fireAt: generated.notificationFireDate)
        }

        return CompletionResult(completedTask: task, generatedTask: generated)
    }

    /// 完了を取り消して再びアクティブに戻す。
    /// `generated` に完了時へ自動生成された次回分を渡すと、それも併せて削除する
    /// （繰り返しタスクを「元に戻す」と次回が二重に残らないようにするため）。
    func reactivate(_ task: Task, removingGenerated generated: Task? = nil) throws {
        let home = task.home
        if task.taskTypeValue == .request {
            task.requestStatusValue = .pending
        } else {
            task.status = TaskStatus.active.rawValue
        }
        task.completedByMemberId = nil
        task.completedAt = nil
        task.updatedAt = Date()

        // 完了時に自動生成された次回分があれば取り消す。
        if let generated, !generated.isDeleted, !generated.isFault || generated.managedObjectContext != nil {
            if let gid = generated.id {
                NotificationService.shared.cancelReminder(taskId: gid)
            }
            context.delete(generated)
        }

        try context.save()
        // 取り消したタスクのリマインダーを再予約する。
        if task.taskTypeValue != .request, let id = task.id {
            NotificationService.shared.scheduleReminder(taskId: id, title: task.resolvedTitle, fireAt: task.notificationFireDate)
        }
        if let home {
            widgetCache.refresh(for: home)
            try context.save()
        }
    }

    /// 完了時に自動生成されたとみられる「次回分」を推定して返す。
    /// 同じ系列でアクティブ、かつ期限が当該タスクより後の最も早いものを採用する。
    func generatedNextOccurrence(of task: Task) -> Task? {
        guard let home = task.home, let seriesId = task.seriesId else { return nil }
        let base = task.dueAt ?? task.completedAt ?? Date()
        return home.tasksArray
            .filter { $0 != task && $0.seriesId == seriesId
                && $0.taskStatusValue == .active
                && ($0.dueAt ?? .distantPast) > base }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            .first
    }
    private func makeNextOccurrence(of task: Task, in home: Home, now: Date) -> Task {
        let next = Task(context: context)
        next.id = UUID()
        next.title = task.title
        next.taskTypeValue = task.taskTypeValue
        next.status = TaskStatus.active.rawValue
        next.notes = task.notes
        next.createdByMemberId = task.createdByMemberId
        next.recurrenceRule = task.recurrenceRule
        next.rotationPolicyValue = task.rotationPolicyValue
        next.effortLevelValue = task.effortLevelValue
        next.visibilityValue = task.visibilityValue
        next.notificationOffsetMinutes = task.notificationOffsetMinutes
        next.isAllDay = task.isAllDay
        next.seriesId = task.seriesId
        next.createdAt = now
        next.updatedAt = now
        next.home = home

        // 次回期限。
        let base = task.dueAt ?? now
        next.dueAt = RecurrenceEngine.nextDate(after: base, rule: task.recurrenceRule, now: now)

        // 担当者。
        switch task.rotationPolicyValue {
        case .fixed:
            next.assignedToMemberId = task.assignedToMemberId
        case .alternate:
            next.assignedToMemberId = RotationResolver.nextAssignee(
                after: task.assignedToMemberId,
                members: home.membersArray
            )
        case .anyone:
            next.assignedToMemberId = nil
        }
        return next
    }

    /// 期限ベースから次回の期限日時を算出する（後方互換のための簡易版・interval=1）。
    static func nextDueDate(from base: Date,
                            frequency: RepeatFrequency,
                            now: Date,
                            calendar: Calendar = .current) -> Date? {
        RecurrenceEngine.nextDate(after: base,
                                  rule: RecurrenceRule(frequency: frequency),
                                  now: now,
                                  calendar: calendar)
    }

    // MARK: - Delete

    func archive(_ task: Task) throws {
        let home = task.home
        task.archivedAt = Date()
        task.status = TaskStatus.archived.rawValue
        task.updatedAt = Date()
        try context.save()
        if let id = task.id {
            NotificationService.shared.cancelReminder(taskId: id)
        }
        if let home { widgetCache.refresh(for: home); try context.save() }
    }

    /// 同じ系列（seriesId）の未完了タスクをまとめてアーカイブする。
    /// 系列 ID がない場合は単体のアーカイブにフォールバックする。
    func deleteSeries(_ task: Task) throws {
        guard let home = task.home, let seriesId = task.seriesId else {
            try archive(task)
            return
        }
        let now = Date()
        let siblings = home.tasksArray.filter { $0.seriesId == seriesId && !$0.isCompleted }
        let targets = siblings.isEmpty ? [task] : siblings
        for sibling in targets {
            sibling.archivedAt = now
            sibling.status = TaskStatus.archived.rawValue
            sibling.updatedAt = now
            if let id = sibling.id {
                NotificationService.shared.cancelReminder(taskId: id)
            }
        }
        try context.save()
        widgetCache.refresh(for: home)
        try context.save()
    }
}

/// 交代制の担当切替ロジック。
enum RotationResolver {
    /// 現在の担当者の次のメンバーを返す。担当未設定なら最初のメンバー。
    static func nextAssignee(after current: UUID?, members: [Member]) -> UUID? {
        let ids = members.compactMap { $0.id }
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return ids.first
        }
        let nextIndex = (index + 1) % ids.count
        return ids[nextIndex]
    }
}
