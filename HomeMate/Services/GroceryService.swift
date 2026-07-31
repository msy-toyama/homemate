//
//  GroceryService.swift
//  HomeMate
//
//  買い物リストの追加・完了。連続追加が3秒以内に終わるよう、追加は最小入力で行う。
//

import CoreData

struct GroceryService {
    let context: NSManagedObjectContext

    private var mentalLoad: MentalLoadService { MentalLoadService(context: context) }
    private var widgetCache: WidgetCacheService { WidgetCacheService(context: context) }

    /// 連続追加用：名前のみで素早く追加する（キーボードは閉じない想定）。
    /// `dueAt` を省略した場合は本日のタスクとして扱う。
    @discardableResult
    func add(in home: Home,
             name: String,
             category: GroceryCategory? = nil,
             quantity: String? = nil,
             dueAt: Date? = nil,
             isAllDay: Bool = true,
             recurrence: RecurrenceRule = .none,
             by member: Member?) throws -> GroceryItem {
        let now = Date()
        let item = GroceryItem(context: context)
        item.id = UUID()
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.categoryValue = category
        item.quantity = quantity
        item.status = GroceryStatus.active.rawValue
        // 指定がなければ本日を期限にする。
        item.dueAt = dueAt ?? now
        item.isAllDay = isAllDay
        item.recurrenceRule = recurrence
        item.seriesId = recurrence.isRepeating ? UUID() : nil
        item.createdByMemberId = member?.id
        item.createdAt = now
        item.updatedAt = now
        item.home = home

        mentalLoad.record(in: home, actorMemberId: member?.id,
                          targetType: .grocery, targetId: item.id, eventType: .notice)

        try context.save()
        widgetCache.refresh(for: home)
        try context.save()
        return item
    }

    /// 既存アイテムのスケジュール（期限・繰り返し）を更新する。
    func updateSchedule(_ item: GroceryItem, dueAt: Date?, isAllDay: Bool = true, recurrence: RecurrenceRule) throws {
        item.dueAt = dueAt
        item.isAllDay = dueAt != nil ? isAllDay : false
        item.recurrenceRule = recurrence
        if recurrence.isRepeating, item.seriesId == nil {
            item.seriesId = UUID()
        } else if !recurrence.isRepeating {
            item.seriesId = nil
        }
        item.updatedAt = Date()
        try context.save()
        if let home = item.home { widgetCache.refresh(for: home); try context.save() }
    }

    @discardableResult
    func complete(_ item: GroceryItem, by member: Member?, now: Date = Date()) throws -> GroceryItem? {
        item.status = GroceryStatus.completed.rawValue
        item.completedByMemberId = member?.id
        item.completedAt = now
        item.updatedAt = now

        let home = item.home
        if let home {
            mentalLoad.record(in: home, actorMemberId: member?.id,
                              targetType: .grocery, targetId: item.id, eventType: .do)
        }

        // 繰り返し設定があれば次回分を生成する。
        var generated: GroceryItem?
        if let home, item.repeatFrequencyValue != .none {
            generated = makeNextOccurrence(of: item, in: home, now: now)
        }

        try context.save()
        if let home {
            widgetCache.refresh(for: home)
            try context.save()
        }
        return generated
    }

    func reactivate(_ item: GroceryItem) throws {
        item.status = GroceryStatus.active.rawValue
        item.completedAt = nil
        item.completedByMemberId = nil
        item.updatedAt = Date()
        try context.save()
        if let home = item.home { widgetCache.refresh(for: home); try context.save() }
    }

    /// 買い物をアーカイブ（ソフト削除）する。一覧からは除外されるがデータは残る。
    func archive(_ item: GroceryItem) throws {
        let home = item.home
        item.archivedAt = Date()
        item.updatedAt = Date()
        try context.save()
        if let home {
            widgetCache.refresh(for: home)
            try context.save()
        }
    }

    /// 繰り返しアイテムの次回分を生成する。
    private func makeNextOccurrence(of item: GroceryItem, in home: Home, now: Date) -> GroceryItem {
        let next = GroceryItem(context: context)
        next.id = UUID()
        next.name = item.name
        next.categoryValue = item.categoryValue
        next.quantity = item.quantity
        next.notes = item.notes
        next.status = GroceryStatus.active.rawValue
        next.recurrenceRule = item.recurrenceRule
        next.isAllDay = item.isAllDay
        next.seriesId = item.seriesId
        next.createdByMemberId = item.createdByMemberId
        next.createdAt = now
        next.updatedAt = now
        next.home = home

        let base = item.dueAt ?? now
        next.dueAt = RecurrenceEngine.nextDate(after: base, rule: item.recurrenceRule, now: now)
        return next
    }
}
