//
//  HouseholdEntitlementService.swift
//  HomeMate
//
//  StoreKit の購入状態を、この端末が所属する各ボード(Home)へ反映する。
//  世帯サブスク: 購入者のボードに premium* を書き込むと NSPersistentCloudKitContainer が
//  CloudKit 同期し、世帯の他メンバー端末も `Home.isPremiumActive` を受け取る。
//

import CoreData
import Foundation

struct HouseholdEntitlementService {
    let context: NSManagedObjectContext

    private func activeHomes() -> [Home] {
        let request = Home.fetchRequest()
        request.predicate = NSPredicate(format: "archivedAt == nil")
        return (try? context.fetch(request)) ?? []
    }

    /// プラス有効時: この端末が「自分」を持つ各ボードを解放する。
    /// `premiumSince` は初回のみ記録（解放開始日を保つ）。
    /// 値が実際に変わったボードだけを書き込み、起動ごとの無意味な
    /// CloudKit 同期（世帯内の書き込み競合）を避ける。
    func applyPlus(productId: String?, expiresAt: Date?) {
        let now = Date()
        var didChange = false
        for home in activeHomes() {
            guard let meId = DeviceIdentityStore.currentMemberId(for: home.id) else { continue }
            var homeChanged = false
            if home.premiumSince == nil { home.premiumSince = now; homeChanged = true }
            if home.premiumUnlockedByMemberId != meId { home.premiumUnlockedByMemberId = meId; homeChanged = true }
            if home.premiumProductId != productId { home.premiumProductId = productId; homeChanged = true }
            if home.premiumExpiresAt != expiresAt { home.premiumExpiresAt = expiresAt; homeChanged = true }
            if homeChanged {
                home.updatedAt = now
                didChange = true
            }
        }
        saveIfNeeded(didChange)
    }

    /// プラス無効時: この端末が解放したボードだけをクリアする。
    /// 世帯内に別の課金者がいる場合、その人の解放（premiumUnlockedByMemberId が別ID）は保持する。
    func revokePlus() {
        var didChange = false
        for home in activeHomes() {
            guard let meId = DeviceIdentityStore.currentMemberId(for: home.id),
                  home.premiumUnlockedByMemberId == meId else { continue }
            home.premiumSince = nil
            home.premiumExpiresAt = nil
            home.premiumProductId = nil
            home.premiumUnlockedByMemberId = nil
            home.updatedAt = Date()
            didChange = true
        }
        saveIfNeeded(didChange)
    }

    /// アクティブなボードのいずれかがプラス解放済みか。
    /// 世帯内の別の課金者による解放（CloudKit 同期）も含めて判定するため、
    /// 非課金メンバー端末でも「世帯がプラス」なら true を返す。
    func hasAnyPremiumHome() -> Bool {
        activeHomes().contains { $0.isPremiumActive }
    }

    private func saveIfNeeded(_ didChange: Bool) {
        guard didChange, context.hasChanges else { return }
        try? context.save()
    }
}
