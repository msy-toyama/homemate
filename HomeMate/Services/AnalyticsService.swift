//
//  AnalyticsService.swift
//  HomeMate
//
//  分析イベントの抽象レイヤー。V1 では OSLog 実装のみ。
//  将来 Firebase / PostHog に差し替える際はこの protocol を実装する。
//
//  重要（設計 27.2）: タスク名・買い物名・お願い内容・個人名・メール・iCloud ID は
//  絶対に送信しない。イベント名とイベント定義済みの非個人パラメータのみを送る。
//

import Foundation
import OSLog

/// 送信を許可する分析イベント（設計 27.1）。
enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case icloudStatusChecked = "icloud_status_checked"
    case homeCreated = "home_created"
    /// 2つ目以降のボード作成（複数ボードは将来の有料候補のため計測）。
    case additionalBoardCreated = "additional_board_created"
    case templateAdded = "template_added"
    case taskCreated = "task_created"
    /// 繰り返し設定付きタスクの作成（繰り返しは将来の有料候補のため計測）。
    case recurringTaskCreated = "recurring_task_created"
    case taskCompleted = "task_completed"
    case groceryCreated = "grocery_created"
    case groceryCompleted = "grocery_completed"
    case requestCreated = "request_created"
    case requestAccepted = "request_accepted"
    case requestCompleted = "request_completed"
    case shareSheetOpened = "share_sheet_opened"
    case memberInviteStarted = "member_invite_started"
    case thanksSent = "thanks_sent"
    case widgetGuideOpened = "widget_guide_opened"
    case widgetTapped = "widget_tapped"
    case weeklyReflectionViewed = "weekly_reflection_viewed"

    // 課金（おうちボード プラス）。金額や個人情報は送らず、遷移計測のみ。
    case paywallShown = "paywall_shown"
    case paywallDismissed = "paywall_dismissed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseRestored = "purchase_restored"
    case purchaseFailed = "purchase_failed"
}

protocol AnalyticsService: AnyObject {
    func track(_ event: AnalyticsEvent, parameters: [String: Any])
}

extension AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        track(event, parameters: [:])
    }
}

/// OSLog に出力するデフォルト実装。個人情報は受け取らない設計。
final class LoggingAnalyticsService: AnalyticsService {
    private let logger = Logger(subsystem: "com.yostfandy.HomeMate", category: "analytics")

    nonisolated init() {}

    func track(_ event: AnalyticsEvent, parameters: [String: Any]) {
        if parameters.isEmpty {
            logger.info("event=\(event.rawValue, privacy: .public)")
        } else {
            // パラメータは数値・列挙値などの非個人データのみを想定する。
            let rendered = parameters
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " ")
            logger.info("event=\(event.rawValue, privacy: .public) \(rendered, privacy: .public)")
        }
    }
}

/// テスト用のイベント記録実装。
final class RecordingAnalyticsService: AnalyticsService {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent, parameters: [String: Any]) {
        events.append(event)
    }
}
