//
//  InviteCodeService.swift
//  HomeMate
//
//  アプリ独自の「招待コード」で世帯共有に参加できるようにする。
//  CloudKit の公開データベースに「コード → 共有URL」の対応を短期保存し、
//  相手はコード入力だけで参加できる（iCloud の生 URL を送らずに済む）。
//
//  セキュリティ:
//  - 共有 URL は所持=アクセス権のケイパビリティ URL のため、コードは十分長い
//    ランダム（曖昧文字を除いた 31 文字 × 8 桁）とし、既定 72 時間で失効させる。
//  - レコード名（= コード）で直接取得するため、公開DBの検索インデックス設定は不要。
//

import CloudKit
import Foundation

struct InviteCodeService {
    private let database: CKDatabase

    private static let recordType = "Invite"
    /// コードの有効期間（72時間）。
    static let ttl: TimeInterval = 60 * 60 * 72
    /// 曖昧な文字（I, L, O, 0, 1）を除いた英数字。
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    private static let codeLength = 8

    init(container: CKContainer = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)) {
        self.database = container.publicCloudDatabase
    }

    struct Invite {
        let shareURL: URL
        let homeName: String
        let expiresAt: Date
    }

    // MARK: - 発行

    /// 共有 URL に対する招待コードを発行し、公開DBへ保存する。発行したコードを返す。
    func create(shareURL: URL, homeName: String) async throws -> String {
        let code = Self.generateCode()
        let record = CKRecord(recordType: Self.recordType,
                              recordID: CKRecord.ID(recordName: Self.recordName(for: code)))
        record["shareURL"] = shareURL.absoluteString as CKRecordValue
        record["homeName"] = homeName as CKRecordValue
        record["expiresAt"] = Date().addingTimeInterval(Self.ttl) as CKRecordValue
        _ = try await database.save(record)
        return code
    }

    // MARK: - 参照

    /// コードから招待情報を取得する。失効していれば削除して `expired` を投げる。
    func lookup(code: String) async throws -> Invite {
        let normalized = Self.normalize(code)
        guard normalized.count == Self.codeLength else { throw InviteCodeError.invalidCode }

        let recordID = CKRecord.ID(recordName: Self.recordName(for: normalized))
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            throw InviteCodeError.notFound
        }

        guard let urlString = record["shareURL"] as? String,
              let url = URL(string: urlString) else {
            throw InviteCodeError.notFound
        }
        let homeName = record["homeName"] as? String ?? ""
        let expiresAt = record["expiresAt"] as? Date ?? .distantPast
        if expiresAt < Date() {
            try? await delete(code: normalized)
            throw InviteCodeError.expired
        }
        return Invite(shareURL: url, homeName: homeName, expiresAt: expiresAt)
    }

    /// コードに対応する公開DBレコードを削除する（ベストエフォート）。
    func delete(code: String) async throws {
        let recordID = CKRecord.ID(recordName: Self.recordName(for: Self.normalize(code)))
        _ = try await database.deleteRecord(withID: recordID)
    }

    // MARK: - ローカルキャッシュ（招待画面の再発行スパムを避ける）

    /// この端末で以前発行し、まだ十分に有効なコードがあれば返す。
    func cachedValidCode(forHomeId homeId: UUID) -> String? {
        let defaults = UserDefaults.standard
        guard let code = defaults.string(forKey: Self.cacheCodeKey(homeId)),
              let expires = defaults.object(forKey: Self.cacheExpiryKey(homeId)) as? Date,
              // 失効間際の再利用を避けるため 30 分のマージンを持たせる。
              expires > Date().addingTimeInterval(30 * 60) else {
            return nil
        }
        return code
    }

    /// 発行したコードと失効時刻を端末ローカルに記録する。
    func cacheCode(_ code: String, forHomeId homeId: UUID) {
        let defaults = UserDefaults.standard
        defaults.set(code, forKey: Self.cacheCodeKey(homeId))
        defaults.set(Date().addingTimeInterval(Self.ttl), forKey: Self.cacheExpiryKey(homeId))
    }

    // MARK: - 整形

    /// 表示用に `XXXX-XXXX` 形式へ整える。
    static func format(_ code: String) -> String {
        let normalized = normalize(code)
        guard normalized.count == codeLength else { return normalized }
        let mid = normalized.index(normalized.startIndex, offsetBy: 4)
        return "\(normalized[..<mid])-\(normalized[mid...])"
    }

    /// 入力コードを正規化（大文字化＋許可文字のみ）。
    static func normalize(_ code: String) -> String {
        code.uppercased().filter { alphabet.contains($0) }
    }

    // MARK: - Private

    private static func generateCode() -> String {
        String((0..<codeLength).map { _ in alphabet.randomElement()! })
    }

    private static func recordName(for code: String) -> String {
        "invite_\(normalize(code).lowercased())"
    }

    private static func cacheCodeKey(_ homeId: UUID) -> String { "inviteCode.\(homeId.uuidString)" }
    private static func cacheExpiryKey(_ homeId: UUID) -> String { "inviteCode.expiry.\(homeId.uuidString)" }
}

enum InviteCodeError: LocalizedError {
    case invalidCode
    case notFound
    case expired
}
