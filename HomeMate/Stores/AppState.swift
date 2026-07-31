//
//  AppState.swift
//  HomeMate
//
//  アプリ全体の状態とサービス依存を保持する。
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let selectedHomeKey = "selectedHomeId"
    private static let tourKey = "hasCompletedTour"
    private static let firstLaunchKey = "firstLaunchDate"

    /// オンボーディング完了フラグ。UserDefaults に永続化する。
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    /// 初回チュートリアル（コーチマーク）の完了フラグ。UserDefaults に永続化する。
    var hasCompletedTour: Bool {
        didSet { UserDefaults.standard.set(hasCompletedTour, forKey: Self.tourKey) }
    }

    /// 現在表示中のボード（Home）の ID。UserDefaults に永続化する。
    var selectedHomeId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedHomeId?.uuidString, forKey: Self.selectedHomeKey)
        }
    }

    /// ディープリンク（homemate://join?code=XXXX）で受け取った招待コード。
    /// セットされると参加シートを自動で提示し、取り込み後に nil に戻す。
    var pendingJoinCode: String?

    @ObservationIgnored let analytics: AnalyticsService

    /// 初回起動日時。将来「カットオフ日以前のユーザーを永久無料/優遇」する
    /// グランドファザリング判定に使う。一度だけ記録し、以後は不変。
    @ObservationIgnored let firstLaunchDate: Date

    init(analytics: AnalyticsService = LoggingAnalyticsService()) {
        self.analytics = analytics
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        self.hasCompletedTour = UserDefaults.standard.bool(forKey: Self.tourKey)
        self.selectedHomeId = UserDefaults.standard.string(forKey: Self.selectedHomeKey)
            .flatMap(UUID.init(uuidString:))
        if let stored = UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date {
            self.firstLaunchDate = stored
        } else {
            let now = Date()
            UserDefaults.standard.set(now, forKey: Self.firstLaunchKey)
            self.firstLaunchDate = now
        }
    }
}
