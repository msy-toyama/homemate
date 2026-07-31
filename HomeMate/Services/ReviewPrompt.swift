//
//  ReviewPrompt.swift
//  HomeMate
//
//  ポジティブな節目（タスク完了の積み重ね）でだけ、控えめにレビューを依頼する。
//  急かしたり繰り返し出したりしない設計。
//

import Foundation

enum ReviewPrompt {
    private static let completionCountKey = "reviewPrompt.completionCount"
    private static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"

    /// レビュー依頼を出すべきタイミングかを判定し、必要なら true を返す。
    /// 一定回数の完了を達成し、かつ今のバージョンでまだ依頼していない場合のみ。
    static func shouldRequestReviewAfterCompletion(
        defaults: UserDefaults = .standard,
        threshold: Int = 10
    ) -> Bool {
        let count = defaults.integer(forKey: completionCountKey) + 1
        defaults.set(count, forKey: completionCountKey)

        guard count >= threshold, count % threshold == 0 else { return false }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = defaults.string(forKey: lastPromptedVersionKey)
        guard lastVersion != currentVersion else { return false }

        defaults.set(currentVersion, forKey: lastPromptedVersionKey)
        return true
    }
}
