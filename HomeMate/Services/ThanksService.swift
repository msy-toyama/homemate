//
//  ThanksService.swift
//  HomeMate
//
//  「ありがとう」リアクションの送信。メンタルロードの thanks も記録する。
//

import CoreData

struct ThanksService {
    let context: NSManagedObjectContext

    private var mentalLoad: MentalLoadService { MentalLoadService(context: context) }

    func sendThanks(in home: Home,
                    from sender: Member?,
                    to recipient: Member?,
                    reaction: ReactionType,
                    targetType: MentalLoadTargetType,
                    targetId: UUID?) throws {
        let now = Date()
        let thanks = ThanksReaction(context: context)
        thanks.id = UUID()
        thanks.fromMemberId = sender?.id
        thanks.toMemberId = recipient?.id
        thanks.reactionTypeValue = reaction
        thanks.targetType = targetType.rawValue
        thanks.targetId = targetId
        thanks.createdAt = now
        thanks.home = home

        mentalLoad.record(in: home, actorMemberId: recipient?.id,
                          targetType: targetType, targetId: targetId, eventType: .thanks)

        try context.save()
    }
}
