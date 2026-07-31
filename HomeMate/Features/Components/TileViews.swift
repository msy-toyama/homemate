//
//  TileViews.swift
//  HomeMate
//
//  リスト画面の「2列タイル」表示で使うカード。行ビュー（RowViews）と同じ情報を
//  コンパクトな正方形寄りのカードにまとめる。スワイプ非対応のため操作はタップ＋コンテキストメニュー。
//

import SwiftUI

/// タスク（家事・お願い）1件のタイル。
struct TaskTile: View {
    /// 管理オブジェクトの属性変更（完了など）を確実に再描画へ反映するため ObservedObject で保持する。
    @ObservedObject var task: Task
    let home: Home
    var onComplete: () -> Void
    var onOpen: (() -> Void)?

    @State private var showEarlyConfirm = false

    private var assignee: Member? { home.member(withID: task.assignedToMemberId) }
    private var typeTint: Color {
        task.taskTypeValue == .request ? HMColor.request : HMColor.chore
    }

    private var dueText: String? {
        guard let due = task.dueAt else { return nil }
        return task.isAllDay
            ? due.formatted(Date.FormatStyle(date: .abbreviated).locale(LanguageManager.activeLocale))
            : due.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(LanguageManager.activeLocale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            HStack(spacing: HMSpacing.s) {
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
                        .font(.system(size: 24))
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

                Spacer(minLength: 0)

                if task.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(HMColor.tertiaryText)
                        .accessibilityLabel("visibility.private")
                }
                if let assignee {
                    MemberBadge(member: assignee, size: 26)
                }
            }

            Text(task.resolvedTitle)
                .font(HMTypography.body)
                .fontWeight(.medium)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? HMColor.secondaryText : HMColor.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                if task.taskTypeValue == .request {
                    Text("board.requests")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(HMColor.request)
                        .padding(.horizontal, HMSpacing.s)
                        .padding(.vertical, 2)
                        .background(HMColor.request.opacity(0.18))
                        .clipShape(Capsule())
                }
                if let dueText {
                    Label(dueText, systemImage: task.isOverdue ? "exclamationmark.circle.fill" : "clock")
                        .font(HMTypography.caption)
                        .foregroundStyle(task.isOverdue ? HMColor.alert : HMColor.secondaryText)
                        .lineLimit(1)
                }
                if let summary = task.recurrenceSummary {
                    Label(summary, systemImage: "repeat")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(HMSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .hmShadow(.soft)
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
}

/// 買い物1件のタイル。
struct GroceryTile: View {
    let item: GroceryItem
    var onToggle: () -> Void
    var onOpen: (() -> Void)?

    /// 今日の期日は省略し、明日以降・期限切れのみラベル化する（GroceryRow と同仕様）。
    private var dueLabel: String? {
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
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            HStack(spacing: HMSpacing.s) {
                Button {
                    if !item.isCompleted { HMHaptics.impact(.light) }
                    onToggle()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(item.isCompleted ? HMColor.success : HMColor.grocery.opacity(0.85))
                        .symbolEffect(.bounce, value: item.isCompleted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("a11y.complete")

                Spacer(minLength: 0)

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

            Text(item.resolvedName)
                .font(HMTypography.body)
                .fontWeight(.medium)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? HMColor.secondaryText : HMColor.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let quantity = item.quantity, !quantity.isEmpty {
                Text(quantity)
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.primaryText.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !item.isCompleted {
                VStack(alignment: .leading, spacing: 4) {
                    if let dueLabel {
                        Label(dueLabel, systemImage: item.isOverdue ? "exclamationmark.circle.fill" : "clock")
                            .font(HMTypography.caption)
                            .foregroundStyle(item.isOverdue ? HMColor.alert : HMColor.secondaryText)
                            .lineLimit(1)
                    }
                    if let summary = item.recurrenceSummary {
                        Label(summary, systemImage: "repeat")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(HMSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .hmShadow(.soft)
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
