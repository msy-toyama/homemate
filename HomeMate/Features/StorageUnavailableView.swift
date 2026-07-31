//
//  StorageUnavailableView.swift
//  HomeMate
//
//  永続ストアの読み込みに失敗したときに表示するフォールバック画面。
//  サイレントに壊れたコンテナで起動し続けるのを防ぎ、ユーザーに復旧手順を案内する。
//

import SwiftUI

struct StorageUnavailableView: View {
    var body: some View {
        VStack(spacing: HMSpacing.l) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(HMColor.alert)
                .accessibilityHidden(true)

            Text("storage.error.title")
                .font(HMTypography.title)
                .foregroundStyle(HMColor.primaryText)
                .multilineTextAlignment(.center)

            Text("storage.error.message")
                .font(HMTypography.body)
                .foregroundStyle(HMColor.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HMSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HMColor.background.ignoresSafeArea())
    }
}

#Preview {
    StorageUnavailableView()
}
