//
//  HMErrorReporter.swift
//  HomeMate
//
//  データ変更（保存・作成・削除など）の失敗をユーザーに気づかせるための共通ハンドラ。
//  これまで `try?` でサイレントに握りつぶしていた箇所を do/catch に置き換え、
//  失敗時にエラーハプティクスとログを残す。
//

import Foundation
import os

enum HMErrorReporter {
    /// 失敗したデータ操作を通知する。エラーハプティクス + ログ出力を行う。
    static func report(_ error: Error,
                       operation: String,
                       logger: Logger) {
        HMHaptics.error()
        logger.error("\(operation, privacy: .public) に失敗: \(error.localizedDescription, privacy: .private)")
    }

    /// throwing な処理を実行し、失敗時は `report` で通知する。
    /// - Returns: 成功したら true、失敗したら false。
    @discardableResult
    static func attempt(_ operation: String,
                        logger: Logger,
                        _ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            report(error, operation: operation, logger: logger)
            return false
        }
    }

    /// 値を返す throwing な処理を実行し、失敗時は `report` で通知して nil を返す。
    static func attemptValue<T>(_ operation: String,
                                logger: Logger,
                                _ work: () throws -> T) -> T? {
        do {
            return try work()
        } catch {
            report(error, operation: operation, logger: logger)
            return nil
        }
    }
}
