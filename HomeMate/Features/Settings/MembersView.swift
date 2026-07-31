//
//  MembersView.swift
//  HomeMate
//
//  メンバー一覧と招待・追加・編集。CloudKit 共有で相手を招く（設計 11章）。
//

import SwiftUI
import CoreData
import CloudKit
import os

private let membersLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "members")

struct MembersView: View {
    let home: Home

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState

    @State private var showInvite = false
    @State private var isPreparingShare = false
    @State private var cloudUnavailable = false
    @State private var cloudErrorIsTransient = false
    @State private var showAddMember = false
    @State private var newMemberName = ""
    @State private var editTarget: MemberEditTarget?
    @State private var showLeaveConfirm = false

    private var members: [Member] { home.membersArray }
    private var canAddMore: Bool { members.count < AppConfig.maxMembersPerHome }
    private var isShared: Bool { home.isShared }
    private var currentMember: Member? { home.currentMember }
    private var isOwner: Bool { currentMember?.roleValue == .owner }

    struct MemberEditTarget: Identifiable {
        let member: Member
        var id: NSManagedObjectID { member.objectID }
    }

    var body: some View {
        Form {
            Section {
                sharingStatusCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(members, id: \.objectID) { member in
                    memberRow(member)
                }
            } header: {
                Text("members.header")
            } footer: {
                Text(LanguageManager.localized("members.count",
                            members.count, AppConfig.maxMembersPerHome))
            }

            Section {
                Button {
                    invite()
                } label: {
                    Label(isShared ? "members.manageInvite" : "members.invite",
                          systemImage: "person.badge.plus")
                }
                .disabled(isPreparingShare || !canAddMore)

                Button {
                    showAddMember = true
                } label: {
                    Label("members.addManual", systemImage: "person.fill.badge.plus")
                }
                .disabled(!canAddMore)
            } footer: {
                if !canAddMore {
                    Text("members.limitReached")
                } else {
                    Text("members.invite.note")
                }
            }

            if isShared, !isOwner, currentMember != nil {
                Section {
                    Button(role: .destructive) {
                        showLeaveConfirm = true
                    } label: {
                        Label("members.leave", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text("members.leave.note")
                }
            }
        }
        .navigationTitle("members.title")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isPreparingShare {
                ProgressView()
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteView(home: home)
        }
        .sheet(item: $editTarget) { target in
            MemberEditView(member: target.member)
        }
        .alert(cloudErrorIsTransient ? "members.cloudTransient.title" : "members.cloudUnavailable.title",
               isPresented: $cloudUnavailable) {
            Button("common.done", role: .cancel) {}
        } message: {
            Text(cloudErrorIsTransient ? "members.cloudTransient.message" : "members.cloudUnavailable.message")
        }
        .alert("members.addManual", isPresented: $showAddMember) {
            TextField("members.addManual.placeholder", text: $newMemberName)
            Button("common.cancel", role: .cancel) { newMemberName = "" }
            Button("common.add") { addManualMember() }
        } message: {
            Text("members.addManual.explainer")
        }
        .confirmationDialog("members.leave.confirm", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("members.leave", role: .destructive) { leaveHome() }
            Button("common.cancel", role: .cancel) {}
        }
    }

    // MARK: - Sharing status

    private var sharingStatusCard: some View {
        let tint = isShared ? HMColor.success : HMColor.accent
        return HMCard(style: .tinted(tint)) {
            HStack(spacing: HMSpacing.m) {
                Image(systemName: isShared ? "person.2.fill" : "iphone")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(isShared ? "members.status.shared" : "members.status.local")
                        .font(HMTypography.heading)
                        .foregroundStyle(HMColor.primaryText)
                    Text(LanguageManager.localized("members.status.count", members.count))
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                }
                Spacer()
            }
        }
    }

    private func memberRow(_ member: Member) -> some View {
        let isMe = member.id == home.currentMember?.id
        return Button {
            HMHaptics.selection()
            editTarget = MemberEditTarget(member: member)
        } label: {
            HStack(spacing: HMSpacing.m) {
                MemberBadge(member: member, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.resolvedDisplayName)
                        .foregroundStyle(HMColor.primaryText)
                    if member.roleValue == .owner {
                        Text("settings.members.owner")
                            .font(.caption)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                }
                Spacer()
                if isMe {
                    Text("members.you")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HMColor.accent)
                        .padding(.horizontal, HMSpacing.s)
                        .padding(.vertical, 2)
                        .background(HMColor.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HMColor.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if member.roleValue != .owner && !isMe {
                Button(role: .destructive) {
                    removeMember(member)
                } label: {
                    Label("members.remove", systemImage: "person.badge.minus")
                }
            }
        }
    }

    // MARK: - Actions

    private func invite() {
        _Concurrency.Task {
            isPreparingShare = true
            defer { isPreparingShare = false }

            let account = await CloudAccountService().currentStatus()
            guard account.canShare else {
                cloudErrorIsTransient = account.isTransient
                cloudUnavailable = true
                return
            }

            // 実際の共有作成・QR/コード発行はブランドされた招待画面側で行う。
            appState.analytics.track(.memberInviteStarted)
            showInvite = true
        }
    }

    private func addManualMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        newMemberName = ""
        guard !trimmed.isEmpty else { return }
        let service = MemberService(context: viewContext)
        HMErrorReporter.attempt("メンバーを追加", logger: membersLogger) {
            try service.addMember(to: home, displayName: trimmed)
        }
    }

    private func removeMember(_ member: Member) {
        let service = MemberService(context: viewContext)
        HMErrorReporter.attempt("メンバーを削除", logger: membersLogger) {
            try service.remove(member)
        }
    }

    private func leaveHome() {
        _Concurrency.Task {
            // まず CloudKit の共有から自分を外す（ベストエフォート）。失敗してもローカル退出は続行する。
            try? await CloudShareService().leaveShare(home)
            let service = MemberService(context: viewContext)
            HMErrorReporter.attempt("ボードから退出", logger: membersLogger) {
                try service.leaveHome(home)
            }
            HMHaptics.impact(.medium)
        }
    }
}
