//
//  BoardSwitcherView.swift
//  HomeMate
//
//  TimeTree 風のボード切り替えシート。
//  すべての共有スペース（ボード）を一覧し、選択・新規作成ができる。
//

import SwiftUI
import CoreData
import os

private let boardsLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "boards")

struct BoardSwitcherView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlementStore

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Home.createdAt, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var homes: FetchedResults<Home>

    @State private var showCreate = false
    @State private var showPaywall = false
    @State private var showJoin = false

    /// 複数ボード作成が解放されているか（誰かが課金した世帯ボード or この端末の購入）。
    private var multiBoardUnlocked: Bool {
        entitlementStore.isUnlocked(.multiBoard, for: homes.first { $0.isPremiumActive })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(homes, id: \.objectID) { home in
                        boardRow(home)
                    }
                }
                Section {
                    Button {
                        if homes.count < AppConfig.freeTierMaxBoards || multiBoardUnlocked {
                            showCreate = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("boards.new", systemImage: "plus.circle.fill")
                                .font(HMTypography.body.weight(.semibold))
                                .foregroundStyle(HMColor.accent)
                            Spacer()
                            if homes.count >= AppConfig.freeTierMaxBoards && !multiBoardUnlocked {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(HMColor.tertiaryText)
                            }
                        }
                    }

                    Button {
                        showJoin = true
                    } label: {
                        Label("boards.join", systemImage: "person.badge.key.fill")
                            .font(HMTypography.body.weight(.semibold))
                            .foregroundStyle(HMColor.accent)
                    }
                } footer: {
                    Text("boards.join.note")
                }
            }
            .navigationTitle("boards.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateBoardView { newHome in
                    appState.selectedHomeId = newHome.id
                    dismiss()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .multiBoard)
            }
            .sheet(isPresented: $showJoin) {
                JoinByCodeView()
            }
        }
    }

    @ViewBuilder
    private func boardRow(_ home: Home) -> some View {
        let isSelected = home.id == appState.selectedHomeId
            || (appState.selectedHomeId == nil && home == homes.first)
        Button {
            appState.selectedHomeId = home.id
            HMHaptics.selection()
            dismiss()
        } label: {
            HStack(spacing: HMSpacing.m) {
                Circle()
                    .fill(home.colorTokenValue.color)
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(home.displayName)
                        .font(HMTypography.body.weight(.semibold))
                        .foregroundStyle(HMColor.primaryText)
                    HStack(spacing: HMSpacing.xs) {
                        Image(systemName: home.isShared ? "person.2.fill" : "person.fill")
                        Text(home.isShared ? "boards.shared" : "boards.private")
                    }
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                }
                Spacer()
                memberAvatars(home)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HMColor.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func memberAvatars(_ home: Home) -> some View {
        let members = home.membersArray.prefix(3)
        HStack(spacing: -8) {
            ForEach(Array(members), id: \.objectID) { member in
                MemberBadge(member: member, size: 24)
            }
        }
    }
}

// MARK: - Create board

struct CreateBoardView: View {
    var onCreated: (Home) -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppState.self) private var appState

    @State private var boardName = ""
    @State private var memberName = ""
    @State private var homeType: HomeType = .roommates
    @State private var createFailed = false

    private var canCreate: Bool {
        !boardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("boards.create.name") {
                    TextField("boards.create.name.placeholder", text: $boardName)
                }
                Section("boards.create.purpose") {
                    Picker("boards.create.purpose", selection: $homeType) {
                        ForEach(HomeType.allCases) { type in
                            Label(type.onboardingTitleKey, systemImage: type.onboardingSymbol)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("boards.create.you") {
                    TextField("onboarding.create.displayName.placeholder", text: $memberName)
                }
            }
            .navigationTitle("boards.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.create") { create() }
                        .disabled(!canCreate)
                }
            }
            .alert("boards.createFailed.title", isPresented: $createFailed) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text("boards.createFailed.message")
            }
        }
    }

    private func create() {
        let service = HomeService(context: viewContext)
        let nickname = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNickname = nickname.isEmpty ? LanguageManager.localized("member.defaultName") : nickname
        do {
            let home = try service.createBoard(name: boardName,
                                               homeType: homeType,
                                               currentMemberName: resolvedNickname,
                                               locale: languageManager.resolvedCode)
            // 2つ目以降のボード作成は将来の有料候補のため、総ボード数とともに計測する。
            let boardCount = service.listHomes().count
            appState.analytics.track(.additionalBoardCreated, parameters: ["board_count": boardCount])
            HMHaptics.success()
            onCreated(home)
            dismiss()
        } catch {
            boardsLogger.error("ボード作成に失敗: \(error.localizedDescription, privacy: .private)")
            createFailed = true
        }
    }
}
