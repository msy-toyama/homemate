//
//  ThanksSheet.swift
//  HomeMate
//
//  完了したタスクに「ありがとう」を伝えるシート。やさしく短く。
//

import SwiftUI
import os

private let thanksLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "thanks")

struct ThanksSheet: View {
    let home: Home
    let recipient: Member
    let targetType: MentalLoadTargetType
    let targetId: UUID?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: HMSpacing.l) {
                MemberBadge(member: recipient, size: 72)
                    .padding(.top, HMSpacing.m)
                Text(LanguageManager.localized("thanks.prompt",
                            recipient.resolvedDisplayName))
                    .font(HMTypography.heading)
                    .multilineTextAlignment(.center)

                HStack(spacing: HMSpacing.m) {
                    ForEach(ReactionType.allCases) { reaction in
                        Button {
                            HMHaptics.success()
                            send(reaction)
                        } label: {
                            VStack(spacing: HMSpacing.xs) {
                                Text(reaction.emoji)
                                    .font(.system(size: 40))
                                Text(reaction.titleKey)
                                    .font(HMTypography.caption)
                                    .foregroundStyle(HMColor.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HMSpacing.m)
                            .background(HMColor.card)
                            .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
                            .hmShadow(.soft)
                        }
                        .buttonStyle(HMPressableStyle(scale: 0.9))
                    }
                }
                Spacer()
            }
            .padding(HMSpacing.l)
            .navigationTitle("thanks.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("thanks.later") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func send(_ reaction: ReactionType) {
        let service = ThanksService(context: viewContext)
        HMErrorReporter.attempt("ありがとうを送信", logger: thanksLogger) {
            try service.sendThanks(in: home,
                                from: home.currentMember,
                                to: recipient,
                                reaction: reaction,
                                targetType: targetType,
                                targetId: targetId)
        }
        appState.analytics.track(.thanksSent)
        dismiss()
    }
}
