//
//  EntitlementStore.swift
//  HomeMate
//
//  機能ゲートの「継ぎ目」。今は無料リリースのため全機能を解放するが、
//  将来このクラスの実装だけを差し替えれば「ボード（世帯）単位の Premium」へ移行できる。
//
//  設計方針:
//  - 課金単位は「ユーザー」ではなく「ボード(Home)」。課金した1人が解放すれば
//    CloudKit 同期される `Home.premiumSince` 経由で世帯全員へ反映される。
//  - 課金ベンダー（StoreKit2 / RevenueCat 等）には非依存。将来の購入状態は
//    `localPurchaseActive` の seam に流し込み、本クラスがゲート判断を一元化する。
//  - 機能ゲートは必ず本クラスの `isUnlocked(_:for:)` を経由すること。
//    ビュー側で `Home.isPremiumActive` を直接参照しない。
//

import Foundation
import Observation

/// 将来 Premium で解放しうる機能の識別子。
/// ゲートを追加する箇所はここに case を足し、`isUnlocked(_:for:)` で判定する。
enum PremiumFeature {
    /// 2つ目以降のボード作成。
    case multiBoard
    /// 無料枠を超えるメンバー追加。
    case extraMembers
    /// 繰り返し（リピート）タスク。
    case recurringTasks
    /// 家事分担の貢献度インサイト。
    case contributionInsights
    /// テーマ / アイコンのカスタマイズ。
    case themes
    /// タスク履歴の閲覧。
    case history
}

@Observable
@MainActor
final class EntitlementStore {

    /// 無料リリース中の全機能解放スイッチ。
    /// Phase 2（課金導入）でこれを `false` にし、`isUnlocked` を本来の判定へ切り替える。
    private let freeLaunchAllUnlocked: Bool

    /// この端末（Apple ID）が有効な購入（プラス）を保持しているか。
    /// StoreKit2 の購読/買い切り状態を `StoreService` から本プロパティへ反映する seam。
    private(set) var localPurchaseActive: Bool = false

    init(freeLaunchAllUnlocked: Bool = true) {
        self.freeLaunchAllUnlocked = freeLaunchAllUnlocked
    }

    /// StoreKit2 の購入状態（プラスが有効か）を反映する。
    /// `StoreService.isPlusActive` の変化に追従して呼び出す唯一の窓口。
    func setLocalPurchaseActive(_ active: Bool) {
        localPurchaseActive = active
    }

    /// 指定機能が、指定ボードで利用可能かどうか。機能ゲートは必ずここを経由する。
    ///
    /// - 無料リリース中: 常に `true`（挙動を一切変えない）。
    /// - Phase 2 以降: `home?.isPremiumActive == true || localPurchaseActive` を返すよう切替。
    func isUnlocked(_ feature: PremiumFeature, for home: Home?) -> Bool {
        if freeLaunchAllUnlocked {
            return true
        }
        // Phase 2 で有効化する本来の判定:
        // ボードが Premium 解放済み（誰かが課金）か、この端末自身が購入済みなら解放。
        if home?.isPremiumActive == true {
            return true
        }
        return localPurchaseActive
    }
}
