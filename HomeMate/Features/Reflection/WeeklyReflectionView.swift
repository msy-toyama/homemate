//
//  WeeklyReflectionView.swift
//  HomeMate
//
//  週次の振り返りカード。順位や赤色を使わず、ふたりの頑張りをやさしく見せる。
//

import SwiftUI

struct WeeklyReflectionView: View {
    let reflection: WeeklyReflection
    /// 「詳しいインサイトを見る」導線。プラス未加入なら Paywall、加入済みなら詳細画面を開く。
    var onDetails: (() -> Void)?
    @State private var animateBars = false

    var body: some View {
        HMCard(style: .tinted(HMColor.accent)) {
            VStack(alignment: .leading, spacing: HMSpacing.m) {
                HStack(spacing: HMSpacing.s) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(HMColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous))
                    Text("reflection.title")
                        .font(HMTypography.heading)
                }

                Text(LanguageManager.localized("reflection.summary",
                            reflection.completedThisWeek, reflection.thanksThisWeek))
                    .font(HMTypography.callout)
                    .foregroundStyle(HMColor.secondaryText)

                ForEach(reflection.contributions) { contribution in
                    contributionRow(contribution)
                }

                Text("reflection.encouragement")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)

                if let onDetails {
                    Button(action: onDetails) {
                        HStack(spacing: HMSpacing.xs) {
                            Text("reflection.insights.more")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .font(HMTypography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(HMColor.accentDeep)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            withAnimation(HMMotion.smooth.delay(0.1)) { animateBars = true }
        }
    }

    private func contributionRow(_ c: MemberContribution) -> some View {
        let maxTotal = max(reflection.contributions.map { $0.total }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: HMSpacing.xs) {
            HStack {
                Circle()
                    .fill(c.colorToken.color)
                    .frame(width: 12, height: 12)
                Text(c.displayName)
                    .font(HMTypography.callout)
                    .fontWeight(.medium)
                Spacer()
                if c.thanksReceived > 0 {
                    Label(LanguageManager.localized("reflection.thanksReceived",
                                 c.thanksReceived), systemImage: "heart.fill")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.accent)
                }
            }
            // やさしいバー（量の可視化のみ。比較・順位ではない）。
            GeometryReader { geo in
                let ratio = CGFloat(c.total) / CGFloat(maxTotal)
                RoundedRectangle(cornerRadius: 4)
                    .fill(c.colorToken.color.opacity(0.22))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(c.colorToken.color.opacity(0.75))
                            .frame(width: max(geo.size.width * ratio * (animateBars ? 1 : 0), 6))
                    }
            }
            .frame(height: 8)

            Text(LanguageManager.localized("reflection.breakdown",
                        c.noticeCount, c.planCount, c.doCount))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(HMColor.secondaryText)
        }
    }
}
