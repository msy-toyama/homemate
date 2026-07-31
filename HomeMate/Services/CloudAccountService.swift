//
//  CloudAccountService.swift
//  HomeMate
//
//  iCloud アカウント状態の確認。共有・同期には iCloud が必要。
//

import CloudKit

enum CloudAccountStatus {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    /// 共有・同期が使えるか。
    var canShare: Bool { self == .available }

    /// 一時的な障害（通信不良など）で、時間をおけば回復し得る状態か。
    /// `noAccount` / `restricted` のような恒久的な状態と区別して、
    /// 「サインインが必要」ではなく「再試行してください」と案内するために使う。
    var isTransient: Bool {
        self == .couldNotDetermine || self == .temporarilyUnavailable
    }
}

struct CloudAccountService {
    func currentStatus() async -> CloudAccountStatus {
        // ユニットテスト実行時はホストアプリが未署名で iCloud エンタイトルメントを
        // 持たないため、CKContainer 生成がトラップする。テスト時は呼び出さない。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .couldNotDetermine
        }
        do {
            let status = try await CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)
                .accountStatus()
            switch status {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .couldNotDetermine
            @unknown default: return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }
}
