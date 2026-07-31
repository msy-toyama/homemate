//
//  MemberEditView.swift
//  HomeMate
//
//  メンバーのプロフィール（表示名・カラー・アバター）を編集するシート。
//

import SwiftUI
import CoreData
import os

private let memberEditLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "memberedit")

struct MemberEditView: View {
    let member: Member

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var color: ColorToken
    @State private var avatar: String

    /// 選べるアバター用 SF Symbol（先頭はイニシャル表示を表すセンチネル）。
    private static let initialsSentinel = "person.circle.fill"
    private let avatarChoices = [
        "person.circle.fill", "heart.fill", "star.fill", "leaf.fill",
        "pawprint.fill", "cup.and.saucer.fill", "moon.fill", "sun.max.fill",
        "bicycle", "gamecontroller.fill", "book.fill", "music.note",
        "flame.fill", "bolt.fill", "crown.fill", "face.smiling.fill"
    ]

    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: HMSpacing.m)]
    private let avatarColumns = [GridItem(.adaptive(minimum: 52), spacing: HMSpacing.m)]

    init(member: Member) {
        self.member = member
        _name = State(initialValue: member.resolvedDisplayName)
        _color = State(initialValue: member.colorTokenValue)
        _avatar = State(initialValue: member.avatarSymbolValue.isEmpty ? Self.initialsSentinel : member.avatarSymbolValue)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "?" : trimmed).prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                Section("memberedit.name") {
                    TextField("memberedit.name.placeholder", text: $name)
                        .font(HMTypography.body)
                }
                Section("memberedit.color") {
                    colorGrid
                }
                Section("memberedit.avatar") {
                    avatarGrid
                }
            }
            .navigationTitle("memberedit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("taskdetail.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                avatarPreview
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var avatarPreview: some View {
        Group {
            if avatar == Self.initialsSentinel {
                Text(initials)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: avatar)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 84, height: 84)
        .background(
            LinearGradient(colors: [color.color, color.color.opacity(0.82)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Circle())
        .hmShadow(.soft)
        .animation(HMMotion.spring, value: color)
        .animation(HMMotion.spring, value: avatar)
    }

    private var colorGrid: some View {
        LazyVGrid(columns: colorColumns, spacing: HMSpacing.m) {
            ForEach(ColorToken.allCases) { token in
                Circle()
                    .fill(token.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(color == token ? 0.9 : 0),
                                              lineWidth: 3)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(color == token ? 1 : 0)
                    )
                    .onTapGesture {
                        HMHaptics.selection()
                        withAnimation(HMMotion.spring) { color = token }
                    }
                    .accessibilityLabel(Text(token.rawValue))
                    .accessibilityAddTraits(color == token ? [.isSelected] : [])
            }
        }
        .padding(.vertical, HMSpacing.xs)
    }

    private var avatarGrid: some View {
        LazyVGrid(columns: avatarColumns, spacing: HMSpacing.m) {
            ForEach(avatarChoices, id: \.self) { symbol in
                let isOn = avatar == symbol
                ZStack {
                    Circle()
                        .fill(isOn ? color.color : HMColor.surface)
                    if symbol == Self.initialsSentinel {
                        Text(initials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(isOn ? Color.white : HMColor.primaryText)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isOn ? Color.white : HMColor.primaryText)
                    }
                }
                .frame(width: 48, height: 48)
                .onTapGesture {
                    HMHaptics.selection()
                    withAnimation(HMMotion.spring) { avatar = symbol }
                }
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(.vertical, HMSpacing.xs)
    }

    // MARK: - Actions

    private func save() {
        let service = MemberService(context: viewContext)
        HMErrorReporter.attempt("メンバーを保存", logger: memberEditLogger) {
            try service.update(member, name: name, color: color, avatarSymbol: avatar)
        }
        HMHaptics.success()
        dismiss()
    }
}
