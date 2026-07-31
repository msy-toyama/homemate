//
//  SampleData.swift
//  HomeMate
//
//  プレビュー・テスト用のサンプルデータ生成。
//

import CoreData

enum SampleData {
    /// サンプルのボード・メンバー・タスク・買い物・お願いを投入し、生成した Home を返す。
    @discardableResult
    static func seed(into context: NSManagedObjectContext) -> Home {
        let now = Date()

        let home = Home(context: context)
        home.id = UUID()
        home.name = "わが家"
        home.homeTypeValue = .roommates
        home.locale = "ja"
        home.isShared = false
        home.createdAt = now
        home.updatedAt = now

        let me = Member(context: context)
        me.id = UUID()
        me.displayName = "わたし"
        me.colorTokenValue = .blue
        me.roleValue = .owner
        me.isCurrentUser = true
        me.joinedAt = now
        me.updatedAt = now
        me.home = home

        let partner = Member(context: context)
        partner.id = UUID()
        partner.displayName = "ルームメイト"
        partner.colorTokenValue = .pink
        partner.roleValue = .member
        partner.isCurrentUser = false
        partner.joinedAt = now
        partner.updatedAt = now
        partner.home = home

        home.ownerMemberId = me.id

        makeTask(in: context, home: home, title: "燃えるゴミを出す",
                 type: .chore, assignedTo: me, due: now.addingTimeInterval(3600),
                 repeatFreq: .weekly, rotation: .alternate)
        makeTask(in: context, home: home, title: "風呂掃除",
                 type: .chore, assignedTo: partner, due: now.addingTimeInterval(7200),
                 repeatFreq: .daily, rotation: .alternate)
        makeTask(in: context, home: home, title: "床に掃除機をかける",
                 type: .chore, assignedTo: nil, due: nil,
                 repeatFreq: .none, rotation: .anyone)

        let request = makeTask(in: context, home: home, title: "帰りに牛乳を買ってきて",
                               type: .request, assignedTo: partner, due: now.addingTimeInterval(10800),
                               repeatFreq: .none, rotation: .fixed)
        request.requestStatusValue = .pending
        request.createdByMemberId = me.id

        for (index, name) in ["牛乳", "卵", "トイレットペーパー", "洗剤", "コーヒー"].enumerated() {
            let item = GroceryItem(context: context)
            item.id = UUID()
            item.name = name
            item.statusValue = .active
            item.createdByMemberId = index.isMultiple(of: 2) ? me.id : partner.id
            item.createdAt = now
            item.updatedAt = now
            item.home = home
        }

        return home
    }

    @discardableResult
    private static func makeTask(in context: NSManagedObjectContext,
                                 home: Home,
                                 title: String,
                                 type: TaskType,
                                 assignedTo member: Member?,
                                 due: Date?,
                                 repeatFreq: RepeatFrequency,
                                 rotation: RotationPolicy) -> Task {
        let now = Date()
        let task = Task(context: context)
        task.id = UUID()
        task.title = title
        task.taskTypeValue = type
        if type == .request {
            task.requestStatusValue = .pending
        } else {
            task.status = TaskStatus.active.rawValue
        }
        task.assignedToMemberId = member?.id
        task.createdByMemberId = home.membersArray.first(where: { $0.isCurrentUser })?.id
        task.dueAt = due
        task.repeatFrequencyValue = repeatFreq
        task.rotationPolicyValue = rotation
        task.effortLevelValue = .normal
        task.createdAt = now
        task.updatedAt = now
        task.home = home
        return task
    }
}
