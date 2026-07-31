//
//  CloudShareService.swift
//  HomeMate
//
//  NSPersistentCloudKitContainer を使ったホームの共有（CKShare）管理。
//  UICloudSharingController に渡す CKShare を生成・取得する。
//

import CoreData
import CloudKit

@MainActor
struct CloudShareService {
    let container: NSPersistentCloudKitContainer

    init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
    }

    /// 既存の共有レコードがあれば返す。
    func existingShare(for home: Home) -> CKShare? {
        guard let shares = try? container.fetchShares(matching: [home.objectID]) else {
            return nil
        }
        return shares[home.objectID]
    }

    /// 招待カードや受け入れダイアログに表示される、アプリ名入りのタイトル。
    static func invitationTitle(for home: Home) -> String {
        LanguageManager.localized("share.invite.title", home.displayName)
    }

    /// ホームを共有可能な状態にし、CKShare と CKContainer を返す。
    func makeShare(for home: Home) async throws -> (CKShare, CKContainer) {
        let shareTitle = Self.invitationTitle(for: home)
        return try await withCheckedThrowingContinuation { continuation in
            container.share([home], to: nil) { _, share, ckContainer, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let share, let ckContainer else {
                    continuation.resume(throwing: CloudShareError.shareUnavailable)
                    return
                }
                share[CKShare.SystemFieldKey.title] = shareTitle as CKRecordValue
                continuation.resume(returning: (share, ckContainer))
            }
        }
    }

    /// 共有を解除する（オーナーのみ）。
    /// CKShare を削除したうえで、ローカルの共有フラグも false に確定させ、
    /// UI の表示（共有中バッジ等）が即座に整合するようにする。
    func stopSharing(_ home: Home) async throws {
        guard let share = existingShare(for: home) else {
            home.isShared = false
            try? home.managedObjectContext?.save()
            return
        }
        let ckContainer = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)
        let database = ckContainer.privateCloudDatabase
        try await database.deleteRecord(withID: share.recordID)
        home.isShared = false
        try? home.managedObjectContext?.save()
    }

    /// 参加者が自分をこの共有から外す。
    /// 参加者側では共有データベースから CKShare を削除することで参加を解消できる。
    /// 以降 NSPersistentCloudKitContainer が同期時に共有データをローカルから取り除く。
    func leaveShare(_ home: Home) async throws {
        guard let share = existingShare(for: home) else { return }
        let ckContainer = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)
        let database = ckContainer.sharedCloudDatabase
        try await database.deleteRecord(withID: share.recordID)
    }

    /// 招待用の共有 URL を返す。既存共有があればその URL、なければ新規作成して取得する。
    /// `CKShare.url` はサーバー保存が確定するまで nil になり得るため、
    /// 少し待って `fetchShares` で取り直すリトライを行う。
    func shareURL(for home: Home) async throws -> URL {
        if let existing = existingShare(for: home), let url = existing.url {
            return url
        }
        let (share, _) = try await makeShare(for: home)
        if let url = share.url {
            return url
        }
        // 保存直後は url が未反映のことがあるため、短い間隔で数回取り直す。
        for _ in 0..<6 {
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000)
            if let refreshed = existingShare(for: home), let url = refreshed.url {
                return url
            }
        }
        throw CloudShareError.shareUnavailable
    }

    /// 招待コード等から得た共有 URL を使って、この端末をボードへ参加させる。
    /// 共有メタデータを取得し、AppDelegate 経由と同じ受け入れ処理へ流す。
    func acceptShare(from url: URL) async throws {
        let metadata = try await fetchShareMetadata(for: url)
        guard let store = container.persistentStoreCoordinator.persistentStores.first else {
            throw CloudShareError.shareUnavailable
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata], into: store) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// 共有 URL から `CKShare.Metadata` を取得する。
    private func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        let ckContainer = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = false
            var fetched: CKShare.Metadata?
            operation.perShareMetadataResultBlock = { _, result in
                if case .success(let metadata) = result {
                    fetched = metadata
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let fetched {
                        continuation.resume(returning: fetched)
                    } else {
                        continuation.resume(throwing: CloudShareError.shareUnavailable)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            ckContainer.add(operation)
        }
    }
}

enum CloudShareError: Error {
    case shareUnavailable
}
