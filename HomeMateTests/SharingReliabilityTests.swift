//
//  SharingReliabilityTests.swift
//  HomeMateTests
//
//  共有・連携まわりの信頼性（重複参加防止・退出・iCloud状態分類）を検証する。
//

import CoreData
import Testing
@testable import HomeMate

struct SharingReliabilityTests {

    // MARK: - iCloud アカウント状態の分類

    @Test func cloudStatusCanShareOnlyWhenAvailable() {
        #expect(CloudAccountStatus.available.canShare)
        #expect(!CloudAccountStatus.noAccount.canShare)
        #expect(!CloudAccountStatus.restricted.canShare)
        #expect(!CloudAccountStatus.temporarilyUnavailable.canShare)
        #expect(!CloudAccountStatus.couldNotDetermine.canShare)
    }

    @Test func cloudStatusTransientOnlyForRecoverableStates() {
        // 一時障害（時間をおけば回復し得る）
        #expect(CloudAccountStatus.couldNotDetermine.isTransient)
        #expect(CloudAccountStatus.temporarilyUnavailable.isTransient)
        // 恒久的な状態は一時障害ではない
        #expect(!CloudAccountStatus.available.isTransient)
        #expect(!CloudAccountStatus.noAccount.isTransient)
        #expect(!CloudAccountStatus.restricted.isTransient)
    }

    // MARK: - 二重参加の防止

    @Test @MainActor func addMemberReusesExistingCurrentUser() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let home = try HomeService(context: context)
            .createHome(name: "共有ボード", homeType: .family, currentMemberName: "オーナー", locale: "ja_JP")

        // createHome がオーナーを「この端末の自分」として登録済み。
        let existingId = try #require(DeviceIdentityStore.currentMemberId(for: home.id))
        let countBefore = home.membersArray.count

        // 同期が追いつく前に再度「自分」を追加しても、重複メンバーは作られない。
        let member = try MemberService(context: context)
            .addMember(to: home, displayName: "重複しないはず", isCurrentUser: true)

        #expect(member.id == existingId)
        #expect(home.membersArray.count == countBefore)
    }

    @Test @MainActor func addMemberStillAddsDistinctMembers() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let home = try HomeService(context: context)
            .createHome(name: "共有ボード", homeType: .family, currentMemberName: "オーナー", locale: "ja_JP")
        let countBefore = home.membersArray.count

        // isCurrentUser=false の通常追加は従来どおり増える。
        _ = try MemberService(context: context).addMember(to: home, displayName: "パートナー")
        #expect(home.membersArray.count == countBefore + 1)
    }

    // MARK: - 退出

    @Test @MainActor func leaveHomeArchivesSelfAndClearsIdentity() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let home = try HomeService(context: context)
            .createHome(name: "退出テスト", homeType: .roommates, currentMemberName: "わたし", locale: "ja_JP")

        let me = try #require(home.currentMember)
        try MemberService(context: context).leaveHome(home)

        #expect(me.archivedAt != nil)
        #expect(DeviceIdentityStore.currentMemberId(for: home.id) == nil)
        #expect(home.currentMember == nil)
    }
}
