//
//  JoinNameBadgeView.swift
//  HomeMate
//
//  CloudKit 共有で参加した直後、自分の名札（メンバー）がまだ無いボードで表示する。
//  表示名を入力すると、このボードに自分のメンバーを作成して紐付ける。
//

import SwiftUI
import CoreData
import UIKit

struct JoinNameBadgeView: View {
    let home: Home

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedColor: ColorToken = .blue
    @State private var saveFailed = false
    @State private var isSaving = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: HMSpacing.l) {
            Spacer(minLength: HMSpacing.l)

            ZStack {
                Circle()
                    .fill(HMColor.success.opacity(0.16))
                    .frame(width: 120, height: 120)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 54))
                    .foregroundStyle(HMColor.success)
            }

            VStack(spacing: HMSpacing.s) {
                Text("join.title")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text(LanguageManager.localized("join.message", home.displayName))
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HMSpacing.l)

            VStack(alignment: .leading, spacing: HMSpacing.s) {
                Text("join.nameLabel")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                TextField("join.namePlaceholder", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)

                colorPicker
                    .padding(.top, HMSpacing.xs)
            }
            .padding(.horizontal, HMSpacing.l)

            Spacer()

            HMPrimaryButton(title: "join.button", isEnabled: !trimmedName.isEmpty && !isSaving) {
                join()
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.m)
        }
        .background(HMColor.background)
        .interactiveDismissDisabled(true)
        .onAppear {
            if displayName.isEmpty {
                displayName = suggestedName()
            }
            selectedColor = nextAvailableColor()
        }
        .alert("join.error.title", isPresented: $saveFailed) {
            Button("common.done", role: .cancel) {}
        } message: {
            Text("join.error.message")
        }
    }

    private var colorPicker: some View {
        HStack(spacing: HMSpacing.s) {
            ForEach(ColorToken.allCases, id: \.self) { token in
                Circle()
                    .fill(token.color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .strokeBorder(HMColor.primaryText.opacity(selectedColor == token ? 0.9 : 0),
                                          lineWidth: 2)
                    )
                    .onTapGesture {
                        selectedColor = token
                        HMHaptics.selection()
                    }
            }
        }
    }

    private func suggestedName() -> String {
        let device = UIDevice.current.name
        // 「〇〇のiPhone」から所有者名だけを取り出す。
        if let range = device.range(of: "の") {
            let owner = String(device[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !owner.isEmpty { return owner }
        }
        if let apostrophe = device.firstIndex(where: { $0 == "'" || $0 == "\u{2019}" }) {
            let owner = String(device[..<apostrophe]).trimmingCharacters(in: .whitespaces)
            if !owner.isEmpty { return owner }
        }
        return ""
    }

    private func nextAvailableColor() -> ColorToken {
        let used = Set(home.membersArray.map { $0.colorTokenValue })
        return ColorToken.allCases.first(where: { !used.contains($0) }) ?? .blue
    }

    private func join() {
        guard !isSaving else { return }
        isSaving = true
        let service = MemberService(context: viewContext)
        do {
            try service.addMember(to: home,
                                  displayName: trimmedName,
                                  color: selectedColor,
                                  isCurrentUser: true,
                                  role: .member)
            HMHaptics.impact(.medium)
            dismiss()
        } catch {
            isSaving = false
            saveFailed = true
        }
    }
}
