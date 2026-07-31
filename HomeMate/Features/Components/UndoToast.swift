//
//  UndoToast.swift
//  HomeMate
//
//  タスク完了を「元に戻す」ためのトースト。完了直後に数秒表示し、
//  タップで直前の完了を取り消す（自動生成された次回分も巻き戻す）。
//

import SwiftUI
import CoreData

/// 取り消し対象の完了を表すトークン。Core Data のオブジェクト ID を保持して安全に復元する。
struct UndoToken: Identifiable, Equatable {
    let id = UUID()
    let completedID: NSManagedObjectID
    let generatedID: NSManagedObjectID?
    var message: LocalizedStringKey = "undo.completed.message"
}

private struct UndoToastModifier: ViewModifier {
    @Binding var token: UndoToken?
    let onUndo: (UndoToken) -> Void
    var autoDismiss: Double = 4

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let token {
                    toast(token)
                        .padding(.horizontal, HMSpacing.m)
                        .padding(.bottom, HMSpacing.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: token.id) {
                            try? await _Concurrency.Task.sleep(for: .seconds(autoDismiss))
                            withAnimation(HMMotion.smooth) { self.token = nil }
                        }
                }
            }
            .animation(HMMotion.smooth, value: token)
    }

    private func toast(_ token: UndoToken) -> some View {
        HStack(spacing: HMSpacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HMColor.success)
            Text(token.message)
                .font(HMTypography.callout)
                .foregroundStyle(HMColor.primaryText)
            Spacer(minLength: HMSpacing.s)
            Button {
                HMHaptics.selection()
                onUndo(token)
                withAnimation(HMMotion.smooth) { self.token = nil }
            } label: {
                Text("undo.action")
                    .font(HMTypography.callout.weight(.bold))
                    .foregroundStyle(HMColor.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HMSpacing.m)
        .padding(.vertical, HMSpacing.s)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .hmShadow(.floating)
    }
}

extension View {
    /// 完了の取り消しトーストを表示する。`token` が設定されると表示し、自動的に消える。
    func undoToast(_ token: Binding<UndoToken?>, onUndo: @escaping (UndoToken) -> Void) -> some View {
        modifier(UndoToastModifier(token: token, onUndo: onUndo))
    }
}
