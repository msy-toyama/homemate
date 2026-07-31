//
//  MemberService.swift
//  HomeMate
//
//  メンバーの追加・編集・退出処理。最大人数は AppConfig.maxMembersPerHome。
//

import CoreData

struct MemberService {
    let context: NSManagedObjectContext

    enum MemberError: Error {
        case limitReached
    }

    var canAddMember: (Home) -> Bool {
        { $0.membersArray.count < AppConfig.maxMembersPerHome }
    }

    @discardableResult
    func addMember(to home: Home,
                   displayName: String,
                   color: ColorToken? = nil,
                   isCurrentUser: Bool = false,
                   role: MemberRole = .member) throws -> Member {
        // 同一端末からの二重参加を防ぐ。既に「この端末の自分」が登録済みなら再利用する。
        // （CloudKit 同期が追いつく前に参加操作を繰り返すと重複 Member が生じ得るため。）
        if isCurrentUser,
           let existingId = DeviceIdentityStore.currentMemberId(for: home.id),
           let existing = home.membersArray.first(where: { $0.id == existingId }) {
            return existing
        }
        guard home.membersArray.count < AppConfig.maxMembersPerHome else {
            throw MemberError.limitReached
        }
        let now = Date()
        let member = Member(context: context)
        member.id = UUID()
        member.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        member.colorTokenValue = color ?? nextColor(for: home)
        member.isCurrentUser = isCurrentUser
        member.roleValue = role
        member.joinedAt = now
        member.updatedAt = now
        member.home = home
        try context.save()
        // 「この端末での自分」として追加された場合は端末ローカル台帳に記録する。
        if isCurrentUser {
            DeviceIdentityStore.setCurrentMember(member.id, for: home.id)
        }
        return member
    }

    func rename(_ member: Member, to name: String) throws {
        member.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        member.updatedAt = Date()
        try context.save()
    }

    func updateColor(_ member: Member, to color: ColorToken) throws {
        member.colorTokenValue = color
        member.updatedAt = Date()
        try context.save()
    }

    /// 表示名・カラー・アバターをまとめて更新する。
    func update(_ member: Member,
                name: String,
                color: ColorToken,
                avatarSymbol: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            member.displayName = trimmed
        }
        member.colorTokenValue = color
        member.avatarSymbolValue = avatarSymbol
        member.updatedAt = Date()
        try context.save()
    }

    /// メンバーを退出させる（データは消さずアーカイブ）。
    func remove(_ member: Member) throws {
        member.archivedAt = Date()
        member.updatedAt = Date()
        try context.save()
    }

    /// 自分がこのホームから退出する（ローカルのメンバーをアーカイブ）。
    /// CloudKit 上の共有解除は共有管理画面（UICloudSharingController）から行う。
    func leaveHome(_ home: Home) throws {
        guard let me = home.currentMember else { return }
        me.archivedAt = Date()
        me.updatedAt = Date()
        try context.save()
        DeviceIdentityStore.clear(for: home.id)
    }

    /// まだ使われていないカラートークンを選ぶ。
    private func nextColor(for home: Home) -> ColorToken {
        let used = Set(home.membersArray.map { $0.colorTokenValue })
        return ColorToken.allCases.first { !used.contains($0) } ?? .blue
    }
}
