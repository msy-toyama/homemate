//
//  StoreService.swift
//  HomeMate
//
//  StoreKit2 の境界。おうちボード プラス（世帯サブスク2種＋買い切り）の
//  製品ロード・購入・復元・エンタイトルメント判定を一手に担う。
//
//  設計:
//  - StoreKit への依存はこのファイルだけに閉じ込める。ゲート判断は EntitlementStore、
//    世帯への反映は HouseholdEntitlementService が担当する。
//  - `isPlusActive` の変化は `onEntitlementChange` で外へ通知し、
//    購入者が属する各ボード(Home)へ premium* を書き込む（世帯解放）。
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreService {

    /// 販売中の製品（年→月→買い切りの順）。
    private(set) var products: [Product] = []
    /// この端末（Apple ID）がプラスを有効に保持しているか。
    private(set) var isPlusActive = false
    /// 現在有効な製品 ID（Home.premiumProductId へ記録する用）。
    private(set) var activeProductId: String?
    /// サブスクの失効時刻（買い切りは nil）。Home.premiumExpiresAt へ記録する用。
    private(set) var expiryDate: Date?
    /// 製品ロード中フラグ。
    private(set) var isLoadingProducts = false
    /// 製品ロードに失敗したか（オフライン等）。
    private(set) var productsLoadFailed = false

    /// エンタイトルメント（プラス状態）が判明・変化したときに呼ばれる。
    /// (active, 製品ID, 失効時刻) を渡し、世帯反映を行わせる。
    var onEntitlementChange: ((_ active: Bool, _ productId: String?, _ expiry: Date?) -> Void)?

    private var updatesTask: _Concurrency.Task<Void, Never>?

    init() {
        // アプリ外での更新（更新・返金・家族共有など）を監視する。
        // StoreService はアプリ生存期間中の常駐のため、監視タスクは明示終了しない。
        updatesTask = _Concurrency.Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    /// 起動時に一度呼ぶ：製品ロード＋現在のエンタイトルメント反映。
    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: AppConfig.PlusProduct.all)
            products = loaded.sorted { displayOrder($0) < displayOrder($1) }
            productsLoadFailed = false
        } catch {
            productsLoadFailed = true
        }
    }

    /// 年→月→買い切りの並び。
    private func displayOrder(_ product: Product) -> Int {
        switch product.id {
        case AppConfig.PlusProduct.yearly: return 0
        case AppConfig.PlusProduct.monthly: return 1
        case AppConfig.PlusProduct.lifetime: return 2
        default: return 9
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// サブスク製品が7日無料トライアル（導入オファー）を持つか。
    func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    // MARK: - Purchase / Restore

    /// 購入を実行する。成功時 true、キャンセル/保留時 false。検証失敗は throw。
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 購入の復元（別端末・再インストール時）。
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// 現在のエンタイトルメントからプラス状態を再計算し、変化を通知する。
    func refreshEntitlements() async {
        var active = false
        var productId: String?
        var expiry: Date?
        var hasLifetime = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let exp = transaction.expirationDate, exp <= Date() { continue }
            guard AppConfig.PlusProduct.all.contains(transaction.productID) else { continue }

            active = true
            let isLifetime = !AppConfig.PlusProduct.subscriptions.contains(transaction.productID)
            // 買い切り(永久)を保有していれば、サブスクの失効日で上書きしない。
            if hasLifetime && !isLifetime { continue }
            productId = transaction.productID
            // サブスクは失効日、買い切り(非消耗)は永久のため nil。
            expiry = isLifetime ? nil : transaction.expirationDate
            if isLifetime { hasLifetime = true }
        }

        isPlusActive = active
        activeProductId = productId
        expiryDate = expiry
        // 変化の有無に関わらず通知し、ボード側の失効時刻も最新化する。
        onEntitlementChange?(active, productId, expiry)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
