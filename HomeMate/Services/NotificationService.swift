//
//  NotificationService.swift
//  HomeMate
//
//  ローカル通知（やさしいリマインダー）。
//  設計方針: 責めない・急かさない文言。「〜しなさい」ではなく「〜はいかがですか」。
//

import Foundation
import UserNotifications
import os

struct NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "homemate.gentleReminder"
    private let logger = Logger(subsystem: "com.yostfandy.HomeMate", category: "notifications")

    /// 通知の利用許可をリクエストする。
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 現在の許可状態を返す。
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 指定した発火日時に、やさしいリマインダーを1件予約する。
    /// 発火日時が過去、または許可がない場合は何もしない。
    /// 通知タイミング（期限の何分前か・終日の基準時刻）の計算は呼び出し側が行う。
    func scheduleReminder(taskId: UUID, title: String, fireAt: Date?) {
        guard let fireAt, fireAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = LanguageManager.localized("notification.reminder.title")
        content.body = LanguageManager.localized("notification.reminder.body", title)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: taskId), content: content, trigger: trigger)

        center.add(request) { [logger] error in
            if let error {
                logger.error("リマインダーの予約に失敗: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    /// 予約済みのリマインダーを取り消す（完了・アーカイブ時など）。
    func cancelReminder(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: taskId)])
    }

    private func identifier(for taskId: UUID) -> String {
        "task-reminder-\(taskId.uuidString)"
    }
}
