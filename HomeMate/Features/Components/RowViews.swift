//
//  RowViews.swift
//  HomeMate
//
//  ボード・リストで共用するタスク／買い物の行ビュー。
//

import SwiftUI

/// タスク（家事・お願い）1件の行。
struct TaskRow: View {
    let task: Task
    let home: Home
    var onComplete: () -> Void
    /// 行（チェックボックス以外）をタップしたときに詳細を開くためのハンドラ。
    var onOpen: (() -> Void)?

    @State private var showEarlyConfirm = false

    private var assignee: Member? { home.member(withID: task.assignedToMemberId) }
    private var typeTint: Color {
        task.taskTypeValue == .request ? HMColor.request : HMColor.chore
    }

    /// メタ情報（種別タグ・期限・繰り返し・写真）が1つでもあるか。
    /// 空の FlowLayout を描画して余白が生まれるのを防ぐ。
    private var hasMeta: Bool {
        task.taskTypeValue == .request
            || task.dueAt != nil
            || task.recurrenceSummary != nil
            || !task.attachmentsArray.isEmpty
    }

    var body: some View {
        HStack(spacing: HMSpacing.m) {
            Button {
                guard !task.isCompleted else { return }
                if task.canCompleteNow() {
                    HMHaptics.success()
                    onComplete()
                } else {
                    showEarlyConfirm = true
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(task.isCompleted ? HMColor.success : typeTint.opacity(0.85))
                    .symbolEffect(.bounce, value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.complete")
            .confirmationDialog("complete.early.title",
                                isPresented: $showEarlyConfirm,
                                titleVisibility: .visible) {
                Button("complete.early.confirm") {
                    HMHaptics.success()
                    onComplete()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("complete.early.message")
            }

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                HStack(spacing: HMSpacing.xs) {
                    if task.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(HMColor.tertiaryText)
                            .accessibilityLabel("visibility.private")
                    }
                    Text(task.resolvedTitle)
                        .font(HMTypography.body)
                        .fontWeight(.medium)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? HMColor.secondaryText : HMColor.primaryText)
                }

                if hasMeta {
                    FlowLayout(spacing: HMSpacing.s, lineSpacing: HMSpacing.s) {
                        if task.taskTypeValue == .request {
                            typeTag("board.requests", tint: HMColor.request)
                        }
                        if let due = task.dueAt {
                            let dueText = task.isAllDay
                                ? due.formatted(Date.FormatStyle(date: .abbreviated)
                                                    .locale(LanguageManager.activeLocale))
                                : due.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                                                    .locale(LanguageManager.activeLocale))
                            Label(dueText,
                                  systemImage: task.isOverdue ? "exclamationmark.circle.fill" : "clock")
                                .font(HMTypography.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(task.isOverdue ? HMColor.alert : HMColor.secondaryText)
                        }
                        if let summary = task.recurrenceSummary {
                            Label(summary, systemImage: "repeat")
                                .font(HMTypography.callout)
                                .foregroundStyle(HMColor.secondaryText)
                        }
                        if !task.attachmentsArray.isEmpty {
                            Label("\(task.attachmentsArray.count)", systemImage: "photo")
                                .font(HMTypography.caption)
                                .foregroundStyle(HMColor.secondaryText)
                                .accessibilityLabel("attachments.photo")
                        }
                    }
                }
            }

            Spacer()

            if let assignee {
                MemberBadge(member: assignee, size: 30)
            }
        }
        .padding(.vertical, HMSpacing.s)
        .opacity(task.isCompleted ? 0.72 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onOpen {
                HMHaptics.selection()
                onOpen()
            }
        }
        .animation(HMMotion.quick, value: task.isCompleted)
    }

    private func typeTag(_ key: LocalizedStringKey, tint: Color) -> some View {
        Text(key)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, HMSpacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18))
            .clipShape(Capsule())
    }
}

/// 買い物1件の行。
struct GroceryRow: View {
    let item: GroceryItem
    var onToggle: () -> Void
    var onOpen: (() -> Void)?

    /// 期日（今日以外のときだけ表示）か繰り返しがある場合に補足行を出す。
    private var dueOrRecurrenceVisible: Bool {
        groceryDueLabel != nil || item.recurrenceSummary != nil
    }

    /// 今日の期日は省略し、明日以降・期限切れのみラベル化する。
    private var groceryDueLabel: String? {
        guard let due = item.dueAt else { return nil }
        let cal = Calendar.current
        let timeSuffix = item.isAllDay
            ? ""
            : " " + due.formatted(Date.FormatStyle(time: .shortened).locale(LanguageManager.activeLocale))
        if cal.isDateInToday(due) {
            return item.isAllDay ? nil : LanguageManager.localized("common.today") + timeSuffix
        }
        if cal.isDateInTomorrow(due) { return LanguageManager.localized("common.tomorrow") + timeSuffix }
        return due.formatted(Date.FormatStyle(date: .abbreviated).locale(LanguageManager.activeLocale)) + timeSuffix
    }

    var body: some View {
        HStack(spacing: HMSpacing.m) {
            Button {
                if !item.isCompleted { HMHaptics.impact(.light) }
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(item.isCompleted ? HMColor.success : HMColor.grocery.opacity(0.85))
                    .symbolEffect(.bounce, value: item.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.complete")

            VStack(alignment: .leading, spacing: HMSpacing.xs) {
                Text(item.resolvedName)
                    .font(HMTypography.body)
                    .fontWeight(.medium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? HMColor.secondaryText : HMColor.primaryText)
                if let quantity = item.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(HMTypography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(HMColor.primaryText.opacity(0.85))
                }
                if !item.isCompleted, dueOrRecurrenceVisible {
                    FlowLayout(spacing: HMSpacing.s, lineSpacing: HMSpacing.s) {
                        if let label = groceryDueLabel {
                            Label(label, systemImage: item.isOverdue ? "exclamationmark.circle.fill" : "clock")
                                .font(HMTypography.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(item.isOverdue ? HMColor.alert : HMColor.secondaryText)
                        }
                        if let summary = item.recurrenceSummary {
                            Label(summary, systemImage: "repeat")
                                .font(HMTypography.callout)
                                .foregroundStyle(HMColor.secondaryText)
                        }
                    }
                }
            }

            Spacer()

            if !item.attachmentsArray.isEmpty {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(HMColor.secondaryText)
                    .accessibilityLabel("attachments.photo")
            }

            if let category = item.categoryValue {
                Text(category.titleKey)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(HMColor.grocery)
                    .padding(.horizontal, HMSpacing.s)
                    .padding(.vertical, 2)
                    .background(HMColor.grocery.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, HMSpacing.s)
        .opacity(item.isCompleted ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onOpen {
                HMHaptics.selection()
                onOpen()
            }
        }
        .animation(HMMotion.quick, value: item.isCompleted)
    }
}
