//
//  HomeService.swift
//  HomeMate
//
//  ボード（Home）とメンバー、初期テンプレートの作成を担当する。
//

import CoreData

struct HomeService {
    let context: NSManagedObjectContext

    /// アーカイブされていないボードを作成日順で返す。
    func listHomes() -> [Home] {
        let request = Home.fetchRequest()
        request.predicate = NSPredicate(format: "archivedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Home.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// 新しいボードと「自分」メンバーを作成する。
    @discardableResult
    func createBoard(name: String,
                     homeType: HomeType,
                     currentMemberName: String,
                     locale: String) throws -> Home {
        try createHome(name: name,
                       homeType: homeType,
                       currentMemberName: currentMemberName,
                       locale: locale)
    }

    /// ボードをアーカイブ（ソフト削除）する。共有中なら呼び出し側で共有解除も検討する。
    func archive(_ home: Home) throws {
        let now = Date()
        home.archivedAt = now
        home.updatedAt = now
        try context.save()
    }

    /// 新しいボードと「自分」メンバーを作成する。
    @discardableResult
    func createHome(name: String,
                    homeType: HomeType,
                    currentMemberName: String,
                    locale: String) throws -> Home {
        let now = Date()

        let home = Home(context: context)
        home.id = UUID()
        home.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        home.homeTypeValue = homeType
        home.locale = locale
        home.isShared = false
        home.createdAt = now
        home.updatedAt = now

        let me = Member(context: context)
        me.id = UUID()
        me.displayName = currentMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        me.colorTokenValue = .blue
        me.roleValue = .owner
        me.isCurrentUser = true
        me.joinedAt = now
        me.updatedAt = now
        me.home = home

        home.ownerMemberId = me.id

        try context.save()
        // 「この端末での自分」を端末ローカルに記録（CloudKit 同期される isCurrentUser に頼らない）。
        DeviceIdentityStore.setCurrentMember(me.id, for: home.id)
        return home
    }

    /// 初期テンプレートからタスク・買い物を投入する。
    func addStarterItems(to home: Home, specs: [TemplateSpec], locale: String) throws {
        let now = Date()
        let meId = home.currentMember?.id

        for (index, spec) in specs.enumerated() {
            switch spec.kind {
            case .chore:
                let task = Task(context: context)
                task.id = UUID()
                task.title = spec.title(for: locale)
                task.taskTypeValue = .chore
                task.status = TaskStatus.active.rawValue
                task.createdByMemberId = meId
                task.rotationPolicyValue = .anyone
                task.effortLevelValue = spec.effort
                task.repeatFrequencyValue = spec.repeatFrequency
                task.seriesId = spec.repeatFrequency != .none ? UUID() : nil
                task.createdAt = now
                task.updatedAt = now
                task.home = home
            case .grocery:
                let item = GroceryItem(context: context)
                item.id = UUID()
                item.name = spec.title(for: locale)
                item.statusValue = .active
                item.category = spec.category?.rawValue
                item.createdByMemberId = meId
                item.createdAt = now
                item.updatedAt = now
                item.home = home
            }

            // テンプレート由来であることを記録（再利用・分析用）。
            let template = TemplateItem(context: context)
            template.id = UUID()
            template.title = spec.title(for: locale)
            template.taskType = spec.kind == .chore ? TaskType.chore.rawValue : "grocery"
            template.category = spec.category?.rawValue
            template.defaultEffort = spec.effort.rawValue
            template.sortOrder = Int16(index)
            template.createdAt = now
            template.home = home
        }

        try context.save()
    }

    /// オンボーディングで選択した家事と買い物を、今日（終日）の予定として追加する。
    func addOnboardingStarters(to home: Home,
                              choreSpecs: [TemplateSpec],
                              groceryNames: [String],
                              locale: String) throws {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let meId = home.currentMember?.id
        var sortOrder: Int16 = 0

        for spec in choreSpecs where spec.kind == .chore {
            let task = Task(context: context)
            task.id = UUID()
            task.title = spec.title(for: locale)
            task.taskTypeValue = .chore
            task.status = TaskStatus.active.rawValue
            task.createdByMemberId = meId
            task.rotationPolicyValue = .anyone
            task.effortLevelValue = spec.effort
            task.repeatFrequencyValue = spec.repeatFrequency
            task.seriesId = spec.repeatFrequency != .none ? UUID() : nil
            task.dueAt = today
            task.isAllDay = true
            task.createdAt = now
            task.updatedAt = now
            task.home = home

            let template = TemplateItem(context: context)
            template.id = UUID()
            template.title = spec.title(for: locale)
            template.taskType = TaskType.chore.rawValue
            template.category = spec.category?.rawValue
            template.defaultEffort = spec.effort.rawValue
            template.sortOrder = sortOrder
            template.createdAt = now
            template.home = home
            sortOrder += 1
        }

        for rawName in groceryNames {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let item = GroceryItem(context: context)
            item.id = UUID()
            item.name = name
            item.statusValue = .active
            item.createdByMemberId = meId
            item.dueAt = today
            item.isAllDay = true
            item.createdAt = now
            item.updatedAt = now
            item.home = home
        }

        try context.save()
    }
}
