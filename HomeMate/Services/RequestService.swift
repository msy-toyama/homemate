//
//  RequestService.swift
//  HomeMate
//
//  「お願い」は taskType=request の Task として扱う。
//  状態は pending / accepted / done / notNow。"notNow" は「今は難しい」であり拒否ではない（設計 17章）。
//

import CoreData

struct RequestService {
    let context: NSManagedObjectContext

    private var mentalLoad: MentalLoadService { MentalLoadService(context: context) }
    private var widgetCache: WidgetCacheService { WidgetCacheService(context: context) }
    private var taskService: TaskService { TaskService(context: context) }

    @discardableResult
    func create(in home: Home,
                title: String,
                assignedTo: Member?,
                dueAt: Date? = nil,
                isAllDay: Bool = false,
                notes: String? = nil,
                by member: Member?) throws -> Task {
        try taskService.create(in: home,
                               title: title,
                               type: .request,
                               assignedTo: assignedTo,
                               dueAt: dueAt,
                               isAllDay: isAllDay,
                               notes: notes,
                               by: member)
    }

    func accept(_ request: Task, by member: Member?) throws {
        request.requestStatusValue = .accepted
        request.updatedAt = Date()
        try context.save()
        if let home = request.home { widgetCache.refresh(for: home); try context.save() }
    }

    func complete(_ request: Task, by member: Member?) throws {
        try taskService.complete(request, by: member)
    }

    /// 「今は難しい」。責めない表現。タスクは消さず状態だけ更新する。
    func markNotNow(_ request: Task, by member: Member?) throws {
        request.requestStatusValue = .notNow
        request.updatedAt = Date()
        try context.save()
        if let home = request.home { widgetCache.refresh(for: home); try context.save() }
    }
}
