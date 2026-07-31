//
//  ThemeManager.swift
//  HomeMate
//
//  おうちボード プラスのテーマ（カラー着せ替え）。
//  選択中テーマを端末ローカルに保持し、`HMColor.accent` / `HMColor.accentDeep` が
//  参照する静的ミラー（`currentAccent` / `currentAccentDeep`）を更新する。
//  これにより既存の全 `HMColor.accent` 参照はコード変更なしでテーマに追従する。
//  画面全体への反映はルートの `.id(...)` 再構築（HomeMateApp）で保証する。
//

import SwiftUI
import Observation

/// 選べるカラーテーマ。既定 `coral` はブランドの `AccentColor` と一致。
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case coral
    case sage
    case ocean
    case lavender
    case sunset
    case forest

    var id: String { rawValue }

    /// 無料でも使える既定テーマ。
    static let free: AppTheme = .coral

    var nameKey: LocalizedStringKey {
        switch self {
        case .coral: return "theme.coral"
        case .sage: return "theme.sage"
        case .ocean: return "theme.ocean"
        case .lavender: return "theme.lavender"
        case .sunset: return "theme.sunset"
        case .forest: return "theme.forest"
        }
    }

    /// 主役アクセント。
    var accent: Color {
        switch self {
        case .coral: return Color("AccentColor")
        case .sage: return Color(red: 0.42, green: 0.63, blue: 0.52)
        case .ocean: return Color(red: 0.28, green: 0.58, blue: 0.74)
        case .lavender: return Color(red: 0.56, green: 0.50, blue: 0.80)
        case .sunset: return Color(red: 0.92, green: 0.52, blue: 0.34)
        case .forest: return Color(red: 0.36, green: 0.56, blue: 0.42)
        }
    }

    /// 押下・強調用の濃いめの色。
    var accentDeep: Color {
        switch self {
        case .coral: return Color(red: 0.86, green: 0.38, blue: 0.30)
        case .sage: return Color(red: 0.32, green: 0.52, blue: 0.42)
        case .ocean: return Color(red: 0.20, green: 0.46, blue: 0.62)
        case .lavender: return Color(red: 0.45, green: 0.39, blue: 0.70)
        case .sunset: return Color(red: 0.82, green: 0.40, blue: 0.24)
        case .forest: return Color(red: 0.27, green: 0.45, blue: 0.33)
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    private static let storageKey = "selectedTheme"

    /// `HMColor` が同期参照する静的ミラー。
    nonisolated(unsafe) static var currentAccent: Color = AppTheme.free.accent
    nonisolated(unsafe) static var currentAccentDeep: Color = AppTheme.free.accentDeep

    var theme: AppTheme {
        didSet {
            guard oldValue != theme else { return }
            persist()
            Self.applyMirror(theme)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .free
        self.theme = stored
        Self.applyMirror(stored)
    }

    /// プラス失効時などに既定テーマへ戻す。
    func resetToFreeIfNeeded(isPlus: Bool) {
        if !isPlus && theme != .free {
            theme = .free
        }
    }

    private func persist() {
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
    }

    private static func applyMirror(_ theme: AppTheme) {
        currentAccent = theme.accent
        currentAccentDeep = theme.accentDeep
    }
}
