//
//  SettingsView.swift
//  HomeMate
//
//  設定画面。メンバー管理・共有は Phase 4 で拡張する。
//

import SwiftUI
import CoreData
import os

private let settingsLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "settings")

struct SettingsView: View {
    let home: Home

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState
    @Environment(LanguageManager.self) private var languageManager
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var boardName: String = ""
    @State private var showSwitcher = false
    @State private var showArchiveConfirm = false
    @State private var showArchiveConfirm2 = false
    @State private var showPaywall = false
    @State private var showThemePicker = false

    /// 管理者（オーナー）かどうか。ボード削除はオーナーのみ実行できる。
    private var isOwner: Bool {
        home.currentMember?.roleValue == .owner
    }

    var body: some View {
        @Bindable var languageManager = languageManager
        NavigationStack {
            Form {
                Section("settings.home") {
                    TextField("settings.home.name", text: $boardName)
                        .onSubmit(saveBoardName)
                    HStack {
                        Label("settings.home.sharing", systemImage: home.isShared ? "person.2.fill" : "person.fill")
                            .foregroundStyle(home.isShared ? HMColor.success : HMColor.secondaryText)
                        Spacer()
                        Text(home.isShared ? "settings.home.sharing.on" : "settings.home.sharing.off")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                    Button {
                        showSwitcher = true
                    } label: {
                        Label("boards.switcher.manage", systemImage: "square.stack.3d.up")
                    }
                }
                Section("settings.members") {
                    NavigationLink {
                        MembersView(home: home)
                    } label: {
                        HStack {
                            Label("members.title", systemImage: "person.2")
                            Spacer()
                            Text("\(home.membersArray.count)")
                                .foregroundStyle(HMColor.secondaryText)
                        }
                    }
                    ForEach(home.membersArray.prefix(3), id: \.objectID) { member in
                        HStack(spacing: HMSpacing.m) {
                            MemberBadge(member: member, size: 24)
                            Text(member.resolvedDisplayName)
                            Spacer()
                            if member.roleValue == .owner {
                                Text("settings.members.owner")
                                    .font(.caption)
                                    .foregroundStyle(HMColor.secondaryText)
                            }
                        }
                    }
                }
                Section("settings.language") {
                    Picker("settings.language.picker", selection: $languageManager.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.titleKey).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("settings.plus") {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("settings.plus")
                                    Text("settings.plus.subtitle")
                                        .font(HMTypography.caption)
                                        .foregroundStyle(HMColor.secondaryText)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(HMColor.accent)
                            }
                            Spacer()
                            if home.isPremiumActive {
                                Text("settings.plus.active")
                                    .font(HMTypography.caption)
                                    .foregroundStyle(HMColor.success)
                            }
                        }
                    }
                    .tint(HMColor.primaryText)
                }
                Section("settings.appearance") {
                    Button {
                        if entitlementStore.isUnlocked(.themes, for: home) {
                            showThemePicker = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("settings.theme", systemImage: "paintpalette")
                            Spacer()
                            if !entitlementStore.isUnlocked(.themes, for: home) {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(HMColor.tertiaryText)
                            }
                        }
                    }
                    .tint(HMColor.primaryText)
                }
                Section("settings.help") {
                    Button {
                        appState.hasCompletedTour = false
                        dismiss()
                    } label: {
                        Label("settings.help.replayTour", systemImage: "questionmark.circle")
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showArchiveConfirm = true
                    } label: {
                        Label("settings.board.archive", systemImage: "archivebox")
                    }
                    .disabled(!isOwner)
                } footer: {
                    if !isOwner {
                        Text("settings.board.delete.ownerOnly")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSwitcher) {
                BoardSwitcherView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .general)
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
            }
            .alert("settings.board.delete.confirm1.title",
                   isPresented: $showArchiveConfirm) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.board.delete.confirm1.button", role: .destructive) {
                    showArchiveConfirm2 = true
                }
            } message: {
                Text("settings.board.delete.confirm1.message")
            }
            .alert("settings.board.delete.confirm2.title",
                   isPresented: $showArchiveConfirm2) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.board.delete.confirm2.button", role: .destructive) {
                    archiveBoard()
                }
            } message: {
                Text("settings.board.delete.confirm2.message")
            }
            .onAppear { boardName = home.displayName }
        }
    }

    private func saveBoardName() {
        let trimmed = boardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != home.name else { return }
        home.name = trimmed
        home.updatedAt = Date()
        HMErrorReporter.attempt("ボード名を保存", logger: settingsLogger) {
            try viewContext.save()
        }
    }

    private func archiveBoard() {
        // 共有中のボードは CloudKit の共有も解除し、参加者側へ削除を伝播させる。
        if home.isShared {
            let target = home
            _Concurrency.Task {
                do {
                    try await CloudShareService().stopSharing(target)
                } catch {
                    settingsLogger.error("共有解除に失敗: \(error.localizedDescription, privacy: .private)")
                }
            }
        }
        let service = HomeService(context: viewContext)
        HMErrorReporter.attempt("ボードをアーカイブ", logger: settingsLogger) {
            try service.archive(home)
        }
        // 残っているボードへ選択を移す。
        appState.selectedHomeId = service.listHomes().first?.id
        dismiss()
    }
}
