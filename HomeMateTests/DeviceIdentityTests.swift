//
//  DeviceIdentityTests.swift
//  HomeMateTests
//
//  端末ローカルの現在メンバー解決と、ボード色の決定性を検証する。
//

import CoreData
import Testing
@testable import HomeMate

@MainActor
struct DeviceIdentityTests {

    // MARK: - DeviceIdentityStore

    @Test func setGetClearRoundTrips() throws {
        let homeId = UUID()
        let memberId = UUID()

        // 念のため初期化
        DeviceIdentityStore.clear(for: homeId)
        #expect(DeviceIdentityStore.currentMemberId(for: homeId) == nil)

        DeviceIdentityStore.setCurrentMember(memberId, for: homeId)
        #expect(DeviceIdentityStore.currentMemberId(for: homeId) == memberId)

        DeviceIdentityStore.clear(for: homeId)
        #expect(DeviceIdentityStore.currentMemberId(for: homeId) == nil)
    }

    @Test func nilHomeIdIsIgnored() {
        // クラッシュせず nil を返すだけ
        DeviceIdentityStore.setCurrentMember(UUID(), for: nil)
        #expect(DeviceIdentityStore.currentMemberId(for: nil) == nil)
    }

    // MARK: - Home.currentMember は端末台帳で解決される

    @Test func currentMemberResolvesFromDeviceRegistry() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let service = HomeService(context: context)

        let home = try service.createHome(name: "テスト", homeType: .family, currentMemberName: "わたし", locale: "ja_JP")

        // createHome がオーナーを台帳に登録しているはず
        #expect(home.currentMember != nil)
        #expect(home.currentMember?.id == home.ownerMemberId)

        // 台帳を消すと currentMember も解決できなくなる（isCurrentUser には依存しない）
        DeviceIdentityStore.clear(for: home.id)
        #expect(home.currentMember == nil)
    }

    // MARK: - colorTokenValue は決定的

    @Test func colorTokenIsStableAcrossCalls() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let service = HomeService(context: context)

        let home = try service.createHome(name: "色テスト", homeType: .family, currentMemberName: "わたし", locale: "ja_JP")

        let first = home.colorTokenValue
        for _ in 0..<10 {
            #expect(home.colorTokenValue == first)
        }
    }

    @Test func colorTokenIsStableForSameId() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let service = HomeService(context: context)

        let homeA = try service.createHome(name: "A", homeType: .family, currentMemberName: "わたし", locale: "ja_JP")
        let idA = homeA.id

        // 同じ id を持つ別オブジェクトでも同じトークンになる（id 由来で決定的）
        let homeB = Home(context: context)
        homeB.id = idA
        #expect(homeB.colorTokenValue == homeA.colorTokenValue)
    }
}
