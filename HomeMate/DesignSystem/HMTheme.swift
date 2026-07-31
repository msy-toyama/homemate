//
//  HMTheme.swift
//  HomeMate
//
//  デザイントークン。あたたかく親しみやすい世界観（温色アクセント・淡色背景・
//  ふんわり影・丸ゴシック寄り）を共通化する。
//

import SwiftUI

// MARK: - Spacing

enum HMSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 44
}

// MARK: - Radius

enum HMRadius {
    static let chip: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 18
    static let large: CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - Color

enum HMColor {
    // 背景
    /// 画面背景。
    static let background = Color(.systemGroupedBackground)
    /// カード背景。
    static let card = Color(.secondarySystemGroupedBackground)
    /// さらに内側の面（チップ等）。
    static let surface = Color(.tertiarySystemGroupedBackground)

    // ブランド／状態
    /// あたたかいアクセント。選択中テーマに追従する（`ThemeManager` がミラーを更新）。
    /// 既定（コーラル）は `AccentColor` アセットと一致。全呼び出し箇所は変更不要。
    static var accent: Color { ThemeManager.currentAccent }
    /// アクセントを少し落ち着けた濃いめの色（押下・強調用）。テーマに追従する。
    static var accentDeep: Color { ThemeManager.currentAccentDeep }
    /// 成功・完了系のグリーン。
    static let success = Color(red: 0.30, green: 0.69, blue: 0.49)
    /// 注意（期限切れのみで使用）。責めない範囲のやわらかい赤。
    static let alert = Color(red: 0.88, green: 0.40, blue: 0.38)

    // 種別カラー（家事 / 買い物 / お願い）
    /// 家事。落ち着いたセージグリーン。
    static let chore = Color(red: 0.34, green: 0.64, blue: 0.58)
    /// 買い物。あたたかいアンバー。
    static let grocery = Color(red: 0.94, green: 0.62, blue: 0.31)
    /// お願い。やわらかいラベンダー。
    static let request = Color(red: 0.55, green: 0.50, blue: 0.82)

    // テキスト
    /// メインテキスト。
    static let primaryText = Color(.label)
    /// 補助テキスト。
    static let secondaryText = Color(.secondaryLabel)
    /// さらに薄いテキスト。
    static let tertiaryText = Color(.tertiaryLabel)

    /// 指定色の淡い塗り（tinted background）。
    static func tint(_ color: Color, _ opacity: Double = 0.12) -> Color {
        color.opacity(opacity)
    }
}

// MARK: - Typography

/// 丸ゴシック寄り（.rounded）で統一。すべて Text Style ベースなので Dynamic Type に追従する。
enum HMTypography {
    /// 統計などの大きな数字。
    static let largeNumber = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// 画面タイトル級。
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    /// セクション見出し。
    static let heading = Font.system(.headline, design: .rounded)
    /// 本文。
    static let body = Font.system(.body, design: .rounded)
    /// やや小さい本文・補足。
    static let callout = Font.system(.callout, design: .rounded)
    /// キャプション。
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)
    /// さらに小さい補足ラベル。
    static let caption2 = Font.system(.caption2, design: .rounded).weight(.semibold)
}

// MARK: - Shadow

struct HMShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// 面にそっと馴染むやわらかい影。
    static let soft = HMShadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    /// カード用の標準影。
    static let card = HMShadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
    /// 浮いている要素（FAB 等）。
    static let floating = HMShadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
}

extension View {
    /// HMShadow を適用する。
    func hmShadow(_ shadow: HMShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Motion

enum HMMotion {
    /// 素早い反応（チェック・トグル）。
    static let quick = Animation.easeOut(duration: 0.18)
    /// なめらかな遷移。
    static let smooth = Animation.easeInOut(duration: 0.28)
    /// 弾むフィードバック（押下・追加）。
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
}

// MARK: - Haptics

enum HMHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
