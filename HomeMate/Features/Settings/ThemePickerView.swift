//
//  ThemePickerView.swift
//  HomeMate
//
//  おうちボード プラスのテーマ選択。選んだ瞬間にミラーが更新され、
//  ルートの `.id` 再構築でアプリ全体のアクセントカラーが切り替わる。
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: HMSpacing.m)]

    var body: some View {
        @Bindable var themeManager = themeManager
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HMSpacing.l) {
                    Text("theme.subtitle")
                        .font(HMTypography.callout)
                        .foregroundStyle(HMColor.secondaryText)

                    LazyVGrid(columns: columns, spacing: HMSpacing.m) {
                        ForEach(AppTheme.allCases) { theme in
                            swatch(theme, isSelected: themeManager.theme == theme) {
                                themeManager.theme = theme
                            }
                        }
                    }
                }
                .padding(HMSpacing.m)
            }
            .background(HMColor.background)
            .navigationTitle("theme.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func swatch(_ theme: AppTheme, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: HMSpacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                        .fill(
                            LinearGradient(colors: [theme.accent, theme.accentDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 64)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                        .strokeBorder(isSelected ? HMColor.primaryText.opacity(0.6) : Color.clear, lineWidth: 2)
                )
                Text(theme.nameKey)
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.primaryText)
            }
        }
        .buttonStyle(HMPressableStyle())
    }
}
