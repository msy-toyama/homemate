//
//  ManagedObjectExtensions.swift
//  HomeMate
//
//  自動生成された NSManagedObject サブクラスに型付きアクセサと
//  便利プロパティを足す拡張。enum と Core Data の String/Int 属性を橋渡しする。
//

import Foundation
import CoreData

// MARK: - Home

extension Home {
    var homeTypeValue: HomeType {
        get { HomeType(rawValue: homeType ?? "") ?? .solo }
        set { homeType = newValue.rawValue }
    }

    /// このボード（世帯）が Premium 解放済みかどうか。
    /// CloudKit 同期される `premiumSince` を真実の源とし、課金した1人が解放すれば
    /// 全メンバーへ反映される。無料枠では誰もセットしないため false。
    /// `premiumExpiresAt` があればその失効時刻も加味する（買い切りは expiresAt=nil で永久）。
    /// これにより、購入者端末がオフラインでクリアできない場合でも
    /// 他メンバー端末が自己失効を判定できる。
    /// 機能ゲートは `EntitlementStore.isUnlocked(_:for:)` を経由して参照すること。
    var isPremiumActive: Bool {
        guard premiumSince != nil else { return false }
        if let expires = premiumExpiresAt {
            return expires > Date()
        }
        return true
    }

    var membersArray: [Member] {
        let set = members as? Set<Member> ?? []
        return set
            .filter { $0.archivedAt == nil }
            .sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
    }

    var tasksArray: [Task] {
        let set = tasks as? Set<Task> ?? []
        return set.filter { $0.archivedAt == nil }
    }

    var groceriesArray: [GroceryItem] {
        let set = groceries as? Set<GroceryItem> ?? []
        return set.filter { $0.archivedAt == nil }
    }

    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LanguageManager.localized("home.defaultName") : trimmed
    }

    /// 現在の端末ユーザーに対応するメンバー。
    /// 真実の源は端末ローカルの DeviceIdentityStore（CloudKit 同期される
    /// `isCurrentUser` は他端末の値が混入するため参照しない）。
    var currentMember: Member? {
        guard let localId = DeviceIdentityStore.currentMemberId(for: id) else { return nil }
        return membersArray.first(where: { $0.id == localId })
    }

    /// 共有で参加したばかりで、まだ自分の名札（メンバー）が無い状態。
    var needsCurrentMemberBadge: Bool {
        isShared && currentMember == nil
    }

    func member(withID id: UUID?) -> Member? {
        guard id != nil else { return nil }
        return membersArray.first(where: { $0.id == id })
    }

    /// ボードを一覧で見分けるための色。id から安定して決まる。
    /// `Hasher` はプロセス毎にシードがランダム化され起動ごとに変わるため使わず、
    /// UUID バイト列から決定的に算出する。
    var colorTokenValue: ColorToken {
        let tokens = ColorToken.allCases
        guard let id, !tokens.isEmpty else { return tokens.first ?? .blue }
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let sum = bytes.reduce(0) { $0 &+ Int($1) }
        let index = sum % tokens.count
        return tokens[index]
    }
}

// MARK: - Member

extension Member {
    var roleValue: MemberRole {
        get { MemberRole(rawValue: role ?? "") ?? .member }
        set { role = newValue.rawValue }
    }

    var colorTokenValue: ColorToken {
        get { ColorToken(rawValue: colorToken ?? "") ?? .blue }
        set { colorToken = newValue.rawValue }
    }

    /// アバターの SF Symbol 名。既定（person.circle.fill）または空ならイニシャル表示。
    var avatarSymbolValue: String {
        get { avatarSymbol ?? "" }
        set { avatarSymbol = newValue }
    }

    /// アバターに SF Symbol を使うか（明示的に既定以外を選んだ場合のみ）。
    var usesAvatarSymbol: Bool {
        let symbol = avatarSymbolValue
        return !symbol.isEmpty && symbol != "person.circle.fill"
    }

    var resolvedDisplayName: String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LanguageManager.localized("member.defaultName") : trimmed
    }
}

// MARK: - Task

extension Task {
    var taskTypeValue: TaskType {
        get { TaskType(rawValue: taskType ?? "") ?? .chore }
        set { taskType = newValue.rawValue }
    }

    /// 汎用ステータス。request タスクの場合は requestStatus からマッピングする。
    var taskStatusValue: TaskStatus {
        if taskTypeValue == .request {
            return requestStatusValue.taskStatus
        }
        return TaskStatus(rawValue: status ?? "") ?? .active
    }

    /// request タスク専用の状態。status 文字列に request の生値を直接格納する。
    var requestStatusValue: RequestStatus {
        get { RequestStatus(rawValue: status ?? "") ?? .pending }
        set { status = newValue.rawValue }
    }

    var rotationPolicyValue: RotationPolicy {
        get { RotationPolicy(rawValue: rotationPolicy ?? "") ?? .fixed }
        set { rotationPolicy = newValue.rawValue }
    }

    var effortLevelValue: EffortLevel {
        get { EffortLevel(rawValue: effortLevel) ?? .normal }
        set { effortLevel = newValue.rawValue }
    }

    var repeatFrequencyValue: RepeatFrequency {
        get { RepeatFrequency(rawValue: repeatFrequency ?? "") ?? .none }
        set { repeatFrequency = newValue == .none ? nil : newValue.rawValue }
    }

    /// 繰り返し間隔（1 以上に正規化）。
    var repeatIntervalValue: Int {
        get { max(1, Int(repeatInterval)) }
        set { repeatInterval = Int16(max(1, newValue)) }
    }

    /// 毎週指定の曜日集合（Calendar 準拠 1=日 … 7=土）。CSV で保存する。
    var repeatWeekdaysSet: Set<Int> {
        get {
            guard let raw = repeatWeekdays, !raw.isEmpty else { return [] }
            return Set(raw.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
        }
        set {
            repeatWeekdays = newValue.isEmpty ? nil : newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// 毎月指定の日（0 = 基準日の日を使用）。
    var repeatDayOfMonthValue: Int {
        get { Int(repeatDayOfMonth) }
        set { repeatDayOfMonth = Int16(max(0, min(31, newValue))) }
    }

    /// 繰り返しルールをまとめて取得・設定する。
    var recurrenceRule: RecurrenceRule {
        get {
            RecurrenceRule(frequency: repeatFrequencyValue,
                           interval: repeatIntervalValue,
                           weekdays: repeatWeekdaysSet,
                           dayOfMonth: repeatDayOfMonthValue)
        }
        set {
            repeatFrequencyValue = newValue.frequency
            repeatIntervalValue = newValue.interval
            repeatWeekdaysSet = newValue.frequency == .weekly ? newValue.weekdays : []
            repeatDayOfMonthValue = newValue.frequency == .monthly ? newValue.dayOfMonth : 0
        }
    }

    /// 表示用の繰り返しサマリ。繰り返しなしのときは nil。アプリの選択言語で整形する。
    var recurrenceSummary: String? {
        let rule = recurrenceRule
        return rule.isRepeating ? rule.summary(locale: LanguageManager.activeLocale) : nil
    }

    /// 公開範囲。
    var visibilityValue: TaskVisibility {
        get { TaskVisibility(rawValue: visibility ?? "") ?? .shared }
        set { visibility = newValue.rawValue }
    }

    /// スケジュール通知のリードタイム（期限の何分前に通知するか）。
    var notificationLeadTimeValue: NotificationLeadTime {
        get { NotificationLeadTime.from(minutes: notificationOffsetMinutes) }
        set { notificationOffsetMinutes = newValue.rawValue }
    }

    /// 通知を実際に発火させる日時。
    /// - 期限なし／通知オフ → nil
    /// - 通常タスク → 期限から `minutesBefore` 分前
    /// - 終日タスク → 期限日の 9:00 を基準に `minutesBefore` 分前
    var notificationFireDate: Date? {
        guard taskTypeValue != .request, let dueAt else { return nil }
        guard let minutesBefore = notificationLeadTimeValue.minutesBefore else { return nil }
        let calendar = Calendar.current
        let anchor: Date
        if isAllDay {
            // 終日は当日 9:00 を通知基準にする。
            anchor = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueAt) ?? dueAt
        } else {
            anchor = dueAt
        }
        return calendar.date(byAdding: .minute, value: -minutesBefore, to: anchor)
    }

    var isPrivate: Bool { visibilityValue == .private }

    var isCompleted: Bool { taskStatusValue == .completed }

    var isOverdue: Bool {
        guard let dueAt, !isCompleted else { return false }
        if isAllDay {
            let calendar = Calendar.current
            return calendar.startOfDay(for: dueAt) < calendar.startOfDay(for: Date())
        }
        return dueAt < Date()
    }

    /// いま完了してよいか。期限なし、または期限日が今日以前なら true。
    /// 期限が翌日以降（未来の予定）のタスクは、完了前に確認を促すために false を返す。
    func canCompleteNow(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueAt else { return true }
        return calendar.startOfDay(for: dueAt) <= calendar.startOfDay(for: now)
    }

    var resolvedTitle: String {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 添付写真を並び順で取得する。
    var attachmentsArray: [Attachment] {
        let set = attachments as? Set<Attachment> ?? []
        return set.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        }
    }
}

// MARK: - GroceryItem

extension GroceryItem {
    var statusValue: GroceryStatus {
        get { GroceryStatus(rawValue: status ?? "") ?? .active }
        set { status = newValue.rawValue }
    }

    var categoryValue: GroceryCategory? {
        get { category.flatMap { GroceryCategory(rawValue: $0) } }
        set { category = newValue?.rawValue }
    }

    var isCompleted: Bool { statusValue == .completed }

    var repeatFrequencyValue: RepeatFrequency {
        get { RepeatFrequency(rawValue: repeatFrequency ?? "") ?? .none }
        set { repeatFrequency = newValue == .none ? nil : newValue.rawValue }
    }

    /// 繰り返し間隔（1 以上に正規化）。
    var repeatIntervalValue: Int {
        get { max(1, Int(repeatInterval)) }
        set { repeatInterval = Int16(max(1, newValue)) }
    }

    /// 毎週指定の曜日集合（Calendar 準拠 1=日 … 7=土）。CSV で保存する。
    var repeatWeekdaysSet: Set<Int> {
        get {
            guard let raw = repeatWeekdays, !raw.isEmpty else { return [] }
            return Set(raw.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
        }
        set {
            repeatWeekdays = newValue.isEmpty ? nil : newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// 毎月指定の日（0 = 基準日の日を使用）。
    var repeatDayOfMonthValue: Int {
        get { Int(repeatDayOfMonth) }
        set { repeatDayOfMonth = Int16(max(0, min(31, newValue))) }
    }

    /// 繰り返しルールをまとめて取得・設定する。
    var recurrenceRule: RecurrenceRule {
        get {
            RecurrenceRule(frequency: repeatFrequencyValue,
                           interval: repeatIntervalValue,
                           weekdays: repeatWeekdaysSet,
                           dayOfMonth: repeatDayOfMonthValue)
        }
        set {
            repeatFrequencyValue = newValue.frequency
            repeatIntervalValue = newValue.interval
            repeatWeekdaysSet = newValue.frequency == .weekly ? newValue.weekdays : []
            repeatDayOfMonthValue = newValue.frequency == .monthly ? newValue.dayOfMonth : 0
        }
    }

    /// 表示用の繰り返しサマリ。繰り返しなしのときは nil。アプリの選択言語で整形する。
    var recurrenceSummary: String? {
        let rule = recurrenceRule
        return rule.isRepeating ? rule.summary(locale: LanguageManager.activeLocale) : nil
    }

    var isOverdue: Bool {
        guard let dueAt, !isCompleted else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: dueAt) < calendar.startOfDay(for: Date())
    }

    var resolvedName: String {
        (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 添付写真を並び順で取得する。
    var attachmentsArray: [Attachment] {
        let set = attachments as? Set<Attachment> ?? []
        return set.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        }
    }
}

// MARK: - MentalLoadEvent

extension MentalLoadEvent {
    var eventTypeValue: MentalLoadEventType? {
        get { eventType.flatMap { MentalLoadEventType(rawValue: $0) } }
        set { eventType = newValue?.rawValue }
    }
}

// MARK: - ThanksReaction

extension ThanksReaction {
    var reactionTypeValue: ReactionType {
        get { ReactionType(rawValue: reactionType ?? "") ?? .thanks }
        set { reactionType = newValue.rawValue }
    }
}
