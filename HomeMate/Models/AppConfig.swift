//
//  AppConfig.swift
//  HomeMate
//
//  アプリ全体で共有する識別子・定数。
//

import Foundation

enum AppConfig {
    /// CloudKit コンテナ識別子（entitlements と一致させる）。
    static let cloudKitContainerIdentifier = "iCloud.com.yostfandy.HomeMate"

    /// App Group 識別子（アプリ本体と Widget で共有）。
    static let appGroupIdentifier = "group.com.yostfandy.HomeMate"

    /// Core Data ストア名。
    static let coreDataModelName = "HomeMate"

    /// 1ボードあたりの最大メンバー数。
    static let maxMembersPerHome = 6

    // MARK: - 将来の課金ティア定数（現在は未使用・無料リリース中は挙動に影響しない）
    // Phase 2（課金導入）で MemberService / ボード作成のゲートに利用する想定。
    // ここを変えるだけで無料枠/有料枠のチューニングができるよう中央化しておく。

    /// 無料枠の最大メンバー数。
    static let freeTierMaxMembers = 6
    /// Premium 解放時の最大メンバー数。
    static let premiumMaxMembers = 6
    /// 無料枠の最大ボード数。
    static let freeTierMaxBoards = 1
    /// Premium 解放時の最大ボード数（0 = 無制限）。
    static let premiumMaxBoards = 0

    // MARK: - 課金（おうちボード プラス / HomeMate Plus）
    // 世帯サブスク。1人が購入すれば CloudKit 同期される Home.premiumSince 経由で
    // 世帯全員へ反映される（EntitlementStore / HouseholdEntitlementService が担当）。

    /// StoreKit の全プラス製品 ID（サブスク2種＋買い切り）。
    enum PlusProduct {
        /// 月額サブスク（7日無料トライアル）。
        static let monthly = "com.yostfandy.HomeMate.plus.monthly"
        /// 年額サブスク（7日無料トライアル・デフォルト表示）。
        static let yearly = "com.yostfandy.HomeMate.plus.yearly"
        /// 買い切り（非消耗・永久）。
        static let lifetime = "com.yostfandy.HomeMate.plus.lifetime"

        /// StoreService がロードする全製品 ID。
        static let all: [String] = [monthly, yearly, lifetime]
        /// サブスク（買い切りを除く）の製品 ID。
        static let subscriptions: Set<String> = [monthly, yearly]
    }

    /// Paywall / 設定に表示する法的リンク。
    /// ⚠️ リリース前に実在の公開 URL へ差し替えること（App Store 審査で必須）。
    enum Legal {
        /// 利用規約。
        static let termsURL = URL(string: "https://msy-toyama.github.io/homemate/terms.html")!
        /// プライバシーポリシー。
        static let privacyURL = URL(string: "https://msy-toyama.github.io/homemate/privacy.html")!
    }
}
