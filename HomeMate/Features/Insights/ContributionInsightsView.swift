//
//  ContributionInsightsView.swift
//  HomeMate
//
//  おうちボード プラスの「詳しい貢献インサイト」。
//  週次カードより一歩踏み込み、メンバーごとの内訳（気づき・段取り・実行・ありがとう・
//  見えない負担）をやさしく可視化する。順位づけ・赤色・比較の煽りはしない。
//

import SwiftUI

struct ContributionInsightsView: View {
    let home: Home

    @Environment(\.dismiss) private var dismiss
    @State private var animate = false

    private var reflection: WeeklyReflection {
        WeeklyReflectionResolver.reflect(for: home)
    }

    private var contributions: [MemberContribution] {
        reflection.contributions
    }

    private var hasData: Bool {
        contributions.contains { $0.total > 0 || $0.thanksReceived > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HMSpacing.l) {
                    header
                    if hasData {
                        ForEach(contributions) { c in
                            memberCard(c)
                        }
                        encouragement
                    } else {
                        emptyState
                    }
                }
                .padding(HMSpacing.m)
            }
            .background(HMColor.background)
            .navigationTitle("insights.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .onAppear {
            withAnimation(HMMotion.smooth.delay(0.1)) { animate = true }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: HMSpacing.xs) {
            Text("insights.subtitle")
                .font(HMTypography.callout)
                .foregroundStyle(HMColor.secondaryText)
        }
    }

    private func memberCard(_ c: MemberContribution) -> some View {
        HMCard(style: .tinted(c.colorToken.color)) {
            VStack(alignment: .leading, spacing: HMSpacing.m) {
                HStack(spacing: HMSpacing.s) {
                    Circle()
                        .fill(c.colorToken.color)
                        .frame(width: 14, height: 14)
                    Text(c.displayName)
                        .font(HMTypography.heading)
                    Spacer()
                    Text(LanguageManager.localized("insights.total") + " \(c.total)")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                }

                statRow(titleKey: "insights.notice", value: c.noticeCount, color: c.colorToken.color)
                statRow(titleKey: "insights.plan", value: c.planCount, color: c.colorToken.color)
                statRow(titleKey: "insights.do", value: c.doCount, color: c.colorToken.color)
                statRow(titleKey: "insights.thanks", value: c.thanksReceived, color: HMColor.accent)

                Divider()

                HStack {
                    Label("insights.invisible", systemImage: "eye.slash")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                    Spacer()
                    Text("\(c.invisibleLoad)")
                        .font(HMTypography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(HMColor.primaryText)
                }
            }
        }
    }

    private func statRow(titleKey: LocalizedStringKey, value: Int, color: Color) -> some View {
        let maxValue = max(categoryMax, 1)
        return VStack(alignment: .leading, spacing: HMSpacing.xs) {
            HStack {
                Text(titleKey)
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                Spacer()
                Text("\(value)")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.primaryText)
            }
            GeometryReader { geo in
                let ratio = CGFloat(value) / CGFloat(maxValue)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.18))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.7))
                            .frame(width: max(geo.size.width * ratio * (animate ? 1 : 0), value > 0 ? 6 : 0))
                    }
            }
            .frame(height: 6)
        }
    }

    /// 全メンバー・全カテゴリを通じた最大値（バーの正規化用）。
    private var categoryMax: Int {
        contributions.flatMap { [$0.noticeCount, $0.planCount, $0.doCount, $0.thanksReceived] }.max() ?? 1
    }

    private var encouragement: some View {
        Text("insights.encouragement")
            .font(HMTypography.caption)
            .foregroundStyle(HMColor.secondaryText)
            .padding(.top, HMSpacing.xs)
    }

    private var emptyState: some View {
        HMCard {
            VStack(spacing: HMSpacing.s) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 28))
                    .foregroundStyle(HMColor.tertiaryText)
                Text("insights.empty")
                    .font(HMTypography.callout)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HMSpacing.m)
        }
    }
}
