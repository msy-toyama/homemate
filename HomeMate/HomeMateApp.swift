//
//  HomeMateApp.swift
//  HomeMate
//
//  Created by 小林将也 on 2026/06/27.
//

import SwiftUI
import CoreData
import CloudKit
import os

private let appLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "app")

extension Notification.Name {
    /// CloudKit 共有の招待を受け入れた直後に通知する。
    /// 参加ボードの選択切替と名札シート表示のトリガーに使う。
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
}

@main
struct HomeMateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @State private var appState = AppState()
    @State private var languageManager = LanguageManager()
    // 課金導入済み: 既定の全解放は無効化し、ボードの Premium 状態と端末購入で判定する。
    @State private var entitlementStore = EntitlementStore(freeLaunchAllUnlocked: false)
    @State private var storeService = StoreService()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if persistenceController.loadError != nil {
                    StorageUnavailableView()
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environment(appState)
                        .environment(languageManager)
                        .environment(entitlementStore)
                        .environment(storeService)
                        .environment(themeManager)
                        .environment(\.locale, languageManager.locale)
                        .id("\(languageManager.language.rawValue)-\(themeManager.theme.rawValue)")
                        .task {
                            DeviceIdentityStore.migrateIfNeeded(context: persistenceController.container.viewContext)
                            appState.analytics.track(.appOpened)
                            configurePurchases()
                            await storeService.start()
                            await requestNotificationsIfHomeExists()
                        }
                }
            }
        }
    }

    /// StoreKit の購入状態を、機能ゲート（EntitlementStore）と世帯反映
    /// （HouseholdEntitlementService）およびテーマ既定戻しへ配線する。
    private func configurePurchases() {
        let context = persistenceController.container.viewContext
        let entitlements = entitlementStore
        let themes = themeManager
        storeService.onEntitlementChange = { active, productId, expiry in
            entitlements.setLocalPurchaseActive(active)
            let household = HouseholdEntitlementService(context: context)
            if active {
                household.applyPlus(productId: productId, expiresAt: expiry)
            } else {
                household.revokePlus()
            }
            // テーマ既定戻しは「世帯がプラスかどうか」で判定する。
            // 非課金メンバーでも、世帯内の課金者が解放していれば（Home.isPremiumActive）
            // 選んだテーマを維持する（毎起動でのリセットを防ぐ）。
            let householdPlus = household.hasAnyPremiumHome()
            themes.resetToFreeIfNeeded(isPlus: active || householdPlus)
        }
    }

    /// オンボーディング済み（ボードがある）ユーザーにだけ、初回に通知許可をやさしく求める。
    private func requestNotificationsIfHomeExists() async {
        let context = persistenceController.container.viewContext
        let request = Home.fetchRequest()
        request.fetchLimit = 1
        let hasHome = (try? context.count(for: request)) ?? 0 > 0
        guard hasHome else { return }
        let status = await NotificationService.shared.authorizationStatus()
        if status == .notDetermined {
            _ = await NotificationService.shared.requestAuthorization()
        }
    }
}

/// CloudKit 共有の招待リンクを受け入れるための AppDelegate。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let container = PersistenceController.shared.container
        guard let store = container.persistentStoreCoordinator.persistentStores.first else {
            appLogger.error("共有受け入れ失敗: 永続ストアが見つかりません")
            return
        }
        container.acceptShareInvitations(from: [cloudKitShareMetadata], into: store) { _, error in
            if let error {
                // 失敗してもクラッシュさせない。UI 側は同期で共有ボードが現れ次第に対応する。
                appLogger.error("CloudKit 共有の受け入れに失敗: \(error.localizedDescription, privacy: .private)")
                return
            }
            // 受け入れ成功。参加ボードの選択・名札シート表示を促す。
            // 実データの取り込みは非同期のため、UI 側はボード出現も監視する。
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: nil)
            }
        }
    }
}
