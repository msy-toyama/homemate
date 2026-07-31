//
//  EntitlementTests.swift
//  HomeMateTests
//
//  課金土台（EntitlementStore / Home.isPremiumActive）の単体テスト。
//  無料リリース中は全機能が解放され挙動が変わらないこと、
//  および Phase 2 切替時のボード単位ゲート判定を検証する。
//

import Testing
import CoreData
import Foundation
@testable import HomeMate

struct EntitlementTests {

    @MainActor
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @MainActor
    private func makeHome(_ ctx: NSManagedObjectContext) throws -> Home {
        try HomeService(context: ctx)
            .createHome(name: "Test", homeType: .roommates, currentMemberName: "Me", locale: "ja")
    }

    private let allFeatures: [PremiumFeature] = [
        .multiBoard, .extraMembers, .recurringTasks,
        .contributionInsights, .themes, .history
    ]

    // MARK: - 無料リリース中は全機能解放（挙動不変）

    @Test @MainActor func freeLaunchUnlocksEverything() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let store = EntitlementStore() // 既定: freeLaunchAllUnlocked = true

        for feature in allFeatures {
            #expect(store.isUnlocked(feature, for: home) == true)
            #expect(store.isUnlocked(feature, for: nil) == true)
        }
    }

    // MARK: - 新規ボードは既定で非 Premium

    @Test @MainActor func freshHomeIsNotPremiumByDefault() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        #expect(home.premiumSince == nil)
        #expect(home.isPremiumActive == false)
    }

    // MARK: - Phase 2: ボード単位ゲート判定

    @Test @MainActor func phase2GatesByBoardPremiumState() throws {
        let ctx = makeContext()
        let freeHome = try makeHome(ctx)
        let store = EntitlementStore(freeLaunchAllUnlocked: false)

        // 無料ボード／home なしはロック。
        #expect(store.isUnlocked(.recurringTasks, for: freeHome) == false)
        #expect(store.isUnlocked(.recurringTasks, for: nil) == false)

        // ボードが Premium 解放されると全メンバー（=このボード参照）で解放。
        freeHome.premiumSince = Date()
        #expect(freeHome.isPremiumActive == true)
        for feature in allFeatures {
            #expect(store.isUnlocked(feature, for: freeHome) == true)
        }
    }

    // MARK: - premiumExpiresAt（失効判定）

    @Test @MainActor func premiumExpiresInPastIsInactive() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        home.premiumSince = Date().addingTimeInterval(-1000)
        home.premiumExpiresAt = Date().addingTimeInterval(-10)
        #expect(home.isPremiumActive == false)
    }

    @Test @MainActor func premiumExpiresInFutureIsActive() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        home.premiumSince = Date()
        home.premiumExpiresAt = Date().addingTimeInterval(3600)
        #expect(home.isPremiumActive == true)
    }

    @Test @MainActor func lifetimeHasNoExpiryStaysActive() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        home.premiumSince = Date()
        home.premiumExpiresAt = nil
        #expect(home.isPremiumActive == true)
    }

    // MARK: - HouseholdEntitlementService（世帯反映）

    @Test @MainActor func applyPlusUnlocksCurrentDeviceHome() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx) // createHome が端末の現在メンバーを登録する。
        let service = HouseholdEntitlementService(context: ctx)
        let expiry = Date().addingTimeInterval(3600)

        service.applyPlus(productId: AppConfig.PlusProduct.yearly, expiresAt: expiry)

        #expect(home.premiumSince != nil)
        #expect(home.premiumProductId == AppConfig.PlusProduct.yearly)
        #expect(home.premiumExpiresAt == expiry)
        #expect(home.isPremiumActive == true)
    }

    @Test @MainActor func revokePlusClearsOwnUnlock() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        let service = HouseholdEntitlementService(context: ctx)
        service.applyPlus(productId: AppConfig.PlusProduct.monthly, expiresAt: nil)
        #expect(home.isPremiumActive == true)

        service.revokePlus()

        #expect(home.premiumSince == nil)
        #expect(home.premiumUnlockedByMemberId == nil)
        #expect(home.isPremiumActive == false)
    }

    @Test @MainActor func revokePlusKeepsOtherPayerUnlock() throws {
        let ctx = makeContext()
        let home = try makeHome(ctx)
        // 世帯内の別の課金者が解放した状態（unlockedBy が自分以外）を模擬。
        home.premiumSince = Date()
        home.premiumUnlockedByMemberId = UUID()

        HouseholdEntitlementService(context: ctx).revokePlus()

        // 他人の解放は保持される。
        #expect(home.premiumSince != nil)
    }
}
