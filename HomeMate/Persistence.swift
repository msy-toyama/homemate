//
//  Persistence.swift
//  HomeMate
//
//  Created by 小林将也 on 2026/06/27.
//

import CoreData
import os

private let persistenceLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "persistence")

struct PersistenceController {
    nonisolated static let shared = PersistenceController()

    /// SwiftUI プレビュー用のインメモリストア。サンプルデータを投入する。
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        SampleData.seed(into: viewContext)
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            assertionFailure("Preview seed failed: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    /// 永続ストアの読み込みに失敗した場合のエラー。成功時は nil。
    /// UI 側でフォールバック画面を表示するために参照する。
    let loadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: AppConfig.coreDataModelName)

        var capturedError: Error?

        // ユニットテスト実行時はホストアプリが未署名で CloudKit エンタイトルメントを
        // 持たないため、CloudKit を無効化してローカルのみで動かす。
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if let description = container.persistentStoreDescriptions.first {
            // 将来のアップデートでモデルを追加的に変更しても、既存データを損なわずに
            // 自動で軽量マイグレーションする（CloudKit 同期は追加変更のみ許容するため、
            // 推論マッピングで安全に移行できる）。既定でも true だが意図を明示する。
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            if inMemory || isTesting {
                description.url = URL(fileURLWithPath: "/dev/null")
                description.cloudKitContainerOptions = nil
            } else {
                // App Group 上にストアを置き、Widget からも参照できるようにする。
                if let groupURL = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
                    description.url = groupURL.appendingPathComponent("HomeMate.sqlite")
                }

                // 履歴トラッキングとリモート変更通知（CloudKit 同期に必要）。
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber,
                                      forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

                // CloudKit コンテナを明示的に設定する。
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: AppConfig.cloudKitContainerIdentifier
                )
            }

            // loadPersistentStores はローカル SQLite ストアでは同期的にコールバックを呼ぶため、
            // ローカル変数で受けてから loadError に確定できる。
            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    // 致命的に落とさず、UI 側でフォールバックを出せるようエラーを保持する。
                    capturedError = error
                    persistenceLogger.error("Core Data ストアの読み込みに失敗: \(error, privacy: .private)")
                }
            }
        } else {
            // ストア記述が見つからない異常系。クラッシュさせず UI でフォールバックする。
            capturedError = PersistenceError.missingStoreDescription
            persistenceLogger.error("永続ストア記述が見つかりません")
        }
        loadError = capturedError

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "viewContext"
    }

    /// バックグラウンド書き込み用のコンテキストを生成する。
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

enum PersistenceError: Error {
    case missingStoreDescription
}
