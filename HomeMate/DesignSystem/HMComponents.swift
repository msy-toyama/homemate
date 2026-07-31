//
//  HMComponents.swift
//  HomeMate
//
//  共通 UI コンポーネント（カード・チップ・主要ボタン・メンバーアイコンなど）。
//

import SwiftUI

// MARK: - Card

/// カードの見た目バリアント。
enum HMCardStyle {
    /// 影なしのフラット。
    case plain
    /// ふんわり影付き（標準）。
    case elevated
    /// 指定色の淡い塗り。
    case tinted(Color)
}

/// 角丸・余白を統一したカードコンテナ。
struct HMCard<Content: View>: View {
    var style: HMCardStyle = .elevated
    var padding: CGFloat = HMSpacing.m
    var cornerRadius: CGFloat = HMRadius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .hmShadow(shadow)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .plain, .elevated:
            HMColor.card
        case .tinted(let color):
            ZStack {
                HMColor.card
                LinearGradient(colors: [color.opacity(0.16), color.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var shadow: HMShadow {
        switch style {
        case .plain:
            return HMShadow(color: .clear, radius: 0, x: 0, y: 0)
        case .elevated, .tinted:
            return .card
        }
    }
}

// MARK: - Button styles

/// 押下で少し縮むフィードバックを与えるボタンスタイル。
struct HMPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(HMMotion.spring, value: configuration.isPressed)
    }
}

// MARK: - Chip

/// 選択可能なタイプチップ。
struct HMChip: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = HMColor.accent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HMHaptics.selection()
            action()
        } label: {
            HStack(spacing: HMSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(HMTypography.callout)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.vertical, HMSpacing.s + 1)
            .background(isSelected ? tint : HMColor.surface)
            .foregroundStyle(isSelected ? Color.white : HMColor.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color(.separator).opacity(0.4),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(HMPressableStyle())
        .animation(HMMotion.quick, value: isSelected)
    }
}

// MARK: - Buttons

/// 画面下部などに置く主要アクションボタン。
struct HMPrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            HMHaptics.impact(.medium)
            action()
        } label: {
            HStack(spacing: HMSpacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(HMTypography.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                Group {
                    if isEnabled { HMColor.accent } else { HMColor.accent.opacity(0.35) }
                }
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.button, style: .continuous))
            .hmShadow(isEnabled ? .soft : HMShadow(color: .clear, radius: 0, x: 0, y: 0))
        }
        .buttonStyle(HMPressableStyle())
        .disabled(!isEnabled)
    }
}

/// 補助アクション用のボタン（淡いアクセント塗り）。
struct HMSecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = HMColor.accent
    let action: () -> Void

    var body: some View {
        Button {
            HMHaptics.impact(.light)
            action()
        } label: {
            HStack(spacing: HMSpacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(HMTypography.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.button, style: .continuous))
        }
        .buttonStyle(HMPressableStyle())
    }
}

// MARK: - MemberBadge

/// メンバーを表す丸いアバター。
struct MemberBadge: View {
    let member: Member
    var size: CGFloat = 32
    var showsRing: Bool = true

    var body: some View {
        let token = member.colorTokenValue
        Group {
            if member.usesAvatarSymbol {
                Image(systemName: member.avatarSymbolValue)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(
            LinearGradient(colors: [token.color, token.color.opacity(0.82)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color(.systemBackground),
                                  lineWidth: showsRing ? max(1.5, size * 0.06) : 0)
        )
        .accessibilityLabel(member.resolvedDisplayName)
    }

    private var initials: String {
        let name = member.resolvedDisplayName
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - StatTile

/// 大きな数字を主役にした統計タイル。今日の進捗（完了件数）も併せて示す。
struct StatTile: View {
    let count: Int
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color
    var sublabel: LocalizedStringKey? = nil
    /// 今日このカテゴリで完了した件数。進捗バーと達成表示に使う。
    var doneToday: Int = 0
    var action: (() -> Void)? = nil

    /// 今日の対応量（残り＋今日完了）。進捗バーの母数。
    private var total: Int { count + doneToday }

    var body: some View {
        if let action {
            Button {
                HMHaptics.selection()
                action()
            } label: {
                tileContent
            }
            .buttonStyle(HMPressableStyle(scale: 0.97))
        } else {
            tileContent
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous))

            Text("\(count)")
                .font(HMTypography.largeNumber)
                .foregroundStyle(count == 0 ? HMColor.success : HMColor.primaryText)
                .contentTransition(.numericText())
                .animation(HMMotion.smooth, value: count)

            Text(titleKey)
                .font(HMTypography.caption)
                .foregroundStyle(HMColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            statusLine

            if total > 0 {
                progressBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HMSpacing.m)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.18), lineWidth: 0.5)
        )
        .hmShadow(.soft)
        .accessibilityElement(children: .combine)
    }

    /// 状態テキスト：全完了なら達成、今日完了があればその件数、なければ既定のサブラベル。
    @ViewBuilder
    private var statusLine: some View {
        Group {
            if count == 0 {
                Label("board.summary.alldone", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(HMColor.success)
            } else if doneToday > 0 {
                Text("board.summary.donetoday \(doneToday)")
                    .foregroundStyle(tint)
            } else if let sublabel {
                Text(sublabel)
                    .foregroundStyle(tint)
            }
        }
        .font(HMTypography.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// 今日の達成割合（完了 / 対応量）を示す細いバー。
    private var progressBar: some View {
        GeometryReader { geo in
            let fraction = total > 0 ? Double(doneToday) / Double(total) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(count == 0 ? HMColor.success : tint)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 4)
        .animation(HMMotion.smooth, value: doneToday)
        .accessibilityHidden(true)
    }
}

// MARK: - Progress ring

/// 今日の進捗を示すアニメーション付きリング。中央に割合や任意のラベルを表示する。
struct HMProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var size: CGFloat = 64
    var tint: Color = HMColor.accent
    var showsPercent: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, clamped))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [tint.opacity(0.55), tint, tint.opacity(0.9)]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.35), radius: 3, x: 0, y: 1)
                .animation(reduceMotion ? nil : HMMotion.spring, value: clamped)
            if showsPercent {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(HMColor.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((clamped * 100).rounded()))%"))
    }
}

// MARK: - Count badge
/// セクションヘッダー等で件数を示す小さなバッジ。
struct HMCountBadge: View {
    let count: Int
    var tint: Color = HMColor.accent

    var body: some View {
        Text("\(count)")
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, HMSpacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }
}

// MARK: - EmptyState

/// 空状態を案内する共通ビュー。任意で CTA を置ける。
struct HMEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint: Color = HMColor.accent
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: HMSpacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 76, height: 76)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(spacing: HMSpacing.xs) {
                Text(title)
                    .font(HMTypography.heading)
                    .foregroundStyle(HMColor.primaryText)
                Text(message)
                    .font(HMTypography.callout)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button {
                    HMHaptics.impact(.light)
                    action()
                } label: {
                    Text(actionTitle)
                        .font(HMTypography.callout)
                        .fontWeight(.semibold)
                        .padding(.horizontal, HMSpacing.l)
                        .padding(.vertical, HMSpacing.s + 2)
                        .background(tint.opacity(0.16))
                        .foregroundStyle(tint)
                        .clipShape(Capsule())
                }
                .buttonStyle(HMPressableStyle())
                .padding(.top, HMSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HMSpacing.l)
    }
}

// MARK: - WeekdayPicker

/// 曜日（複数）を丸ボタンで選択するピッカー。Calendar 準拠で 1=日曜 … 7=土曜。
/// 並びは端末の週開始（firstWeekday）に追従する。
struct HMWeekdayPicker: View {
    @Binding var selection: Set<Int>
    var tint: Color = HMColor.accent

    private let calendar = Calendar.current

    /// firstWeekday 始まりに並べた曜日番号の配列。
    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    /// ロケールに合わせた1〜2文字の曜日名（index 0=日 … 6=土）。
    private var symbols: [String] {
        calendar.veryShortWeekdaySymbols
    }

    var body: some View {
        HStack(spacing: HMSpacing.xs) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    HMHaptics.selection()
                    if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(symbolFor(weekday))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(isOn ? tint : HMColor.surface)
                        .foregroundStyle(isOn ? Color.white : HMColor.primaryText)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(isOn ? Color.clear : Color(.separator).opacity(0.35),
                                                   lineWidth: 1)
                        )
                }
                .buttonStyle(HMPressableStyle())
                .accessibilityLabel(Text(accessibilityName(weekday)))
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .animation(HMMotion.quick, value: selection)
    }

    private func symbolFor(_ weekday: Int) -> String {
        let index = weekday - 1
        guard index >= 0, index < symbols.count else { return "?" }
        return symbols[index]
    }

    private func accessibilityName(_ weekday: Int) -> String {
        let index = weekday - 1
        let names = calendar.weekdaySymbols
        guard index >= 0, index < names.count else { return "" }
        return names[index]
    }
}

// MARK: - InfoRow

/// ラベル＋値（任意でアイコン）を1行に並べる、タップ可能な設定行。
struct HMNavRow: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var value: String?
    var tint: Color = HMColor.accent
    let action: () -> Void

    var body: some View {
        Button {
            HMHaptics.selection()
            action()
        } label: {
            HStack(spacing: HMSpacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24)
                }
                Text(title)
                    .foregroundStyle(HMColor.primaryText)
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(HMColor.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HMColor.tertiaryText)
            }
            .font(HMTypography.body)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
