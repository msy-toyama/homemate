//
//  LanguageManager.swift
//  HomeMate
//
//  アプリ内の言語切り替えを管理する。
//  - 初回ダウンロード時は端末の言語から自動判定（日本語なら ja、それ以外は en）。
//  - 設定画面からいつでも「システムに従う / 日本語 / English」を選べる。
//  - 再起動なしで即時に切り替わるよう、Bundle.main の文字列解決を差し替える。
//

import Foundation
import SwiftUI
import Observation

/// アプリがサポートする言語の選択肢。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case ja
    case en

    var id: String { rawValue }

    /// 設定画面で表示するラベルのローカライズキー。
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "language.system"
        case .ja: return "language.japanese"
        case .en: return "language.english"
        }
    }
}

/// Bundle.main の `localizedString(forKey:value:table:)` を、
/// 選択中の言語の .lproj から解決するよう差し替えるためのサブクラス。
private final class LanguageAwareBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageManager.activeBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

@Observable
@MainActor
final class LanguageManager {
    private static let storageKey = "appLanguage"

    /// 現在選択中の言語の .lproj バンドル。`LanguageAwareBundle` から参照される。
    nonisolated(unsafe) static var activeBundle: Bundle?
    /// 日付・曜日・数値の整形をアプリの選択言語に合わせるためのロケール。
    /// SwiftUI の環境ロケールを参照しない `.formatted` や `RecurrenceRule.summary` から利用する。
    nonisolated(unsafe) static var activeLocale: Locale = .current
    private static var didSwizzleMainBundle = false

    /// ユーザーが選んだ言語設定。変更すると即座にアプリ全体へ反映する。
    var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            apply()
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
        apply()
    }

    /// 実際に表示に使う言語コード（"ja" または "en"）。
    var resolvedCode: String {
        switch language {
        case .ja:
            return "ja"
        case .en:
            return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("ja") ? "ja" : "en"
        }
    }

    /// SwiftUI の `\.locale` 環境値に渡すロケール。
    var locale: Locale { Locale(identifier: resolvedCode) }

    /// アプリ内で選択中の言語に従って文字列を解決する。
    ///
    /// `String(localized:)` は新しい Foundation のローカライズ機構を使うため、
    /// `Bundle.main` を差し替える `LanguageAwareBundle` を経由せず、
    /// システム言語の文字列を返してしまう。表示用の文字列はこのヘルパを使うことで、
    /// 設定画面で選んだ言語（`activeBundle`）に確実に従わせる。
    nonisolated static func localized(_ key: String, _ args: CVarArg...) -> String {
        let bundle = activeBundle ?? .main
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        if args.isEmpty {
            return format
        }
        return String(format: format, locale: activeLocale, arguments: args)
    }

    private func apply() {
        if !Self.didSwizzleMainBundle {
            object_setClass(Bundle.main, LanguageAwareBundle.self)
            Self.didSwizzleMainBundle = true
        }

        let code = resolvedCode
        Self.activeLocale = Locale(identifier: code)
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            Self.activeBundle = bundle
        } else {
            Self.activeBundle = nil
        }
    }
}
