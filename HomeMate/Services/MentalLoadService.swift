//
//  MentalLoadService.swift
//  HomeMate
//
//  メンタルロード（見えない生活負担）を相手を責めずに記録する。
//  notice / plan / do / thanks の4種類を裏側で自動記録する（設計 19章）。
//

import CoreData

struct MentalLoadService {
    let context: NSManagedObjectContext

    func record(in home: Home,
                actorMemberId: UUID?,
                targetType: MentalLoadTargetType,
                targetId: UUID?,
                eventType: MentalLoadEventType) {
        let event = MentalLoadEvent(context: context)
        event.id = UUID()
        event.actorMemberId = actorMemberId
        event.targetType = targetType.rawValue
        event.targetId = targetId
        event.eventTypeValue = eventType
        event.createdAt = Date()
        event.home = home

        switch eventType {
        case .notice: event.noticePoints = 1
        case .plan: event.planPoints = 1
        case .do: event.doPoints = 1
        case .thanks: event.thanksPoints = 1
        }
    }
}
