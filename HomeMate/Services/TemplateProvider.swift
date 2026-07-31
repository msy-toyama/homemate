//
//  TemplateProvider.swift
//  HomeMate
//
//  ボードタイプ別の初期テンプレート（おすすめの家事・買い物）。
//  タイトルはユーザーデータとして保存するため、ロケールに応じて日本語/英語を選ぶ。
//

import Foundation

/// テンプレート1件の定義。
struct TemplateSpec: Identifiable {
    enum Kind {
        case chore
        case grocery
    }

    let id = UUID()
    let kind: Kind
    let titleJa: String
    let titleEn: String
    var category: GroceryCategory? = nil
    var effort: EffortLevel = .normal
    var repeatFrequency: RepeatFrequency = .none

    func title(for locale: String) -> String {
        locale.hasPrefix("ja") ? titleJa : titleEn
    }
}

enum TemplateProvider {
    /// 指定したボードタイプのおすすめ初期アイテムを返す。
    static func starterItems(for homeType: HomeType) -> [TemplateSpec] {
        starterChores(for: homeType) + commonGroceries
    }

    /// おすすめの家事だけを返す（オンボーディングの複数選択用）。
    static func starterChores(for homeType: HomeType) -> [TemplateSpec] {
        commonChores
    }

    /// おすすめの買い物だけを返す（オンボーディングの買い物ヒアリング用）。
    static func starterGroceries(for homeType: HomeType) -> [TemplateSpec] {
        commonGroceries
    }

    private static let commonChores: [TemplateSpec] = [
        TemplateSpec(kind: .chore, titleJa: "朝食を作る", titleEn: "Make breakfast",
                     effort: .light, repeatFrequency: .daily),
        TemplateSpec(kind: .chore, titleJa: "夕食を作る", titleEn: "Make dinner",
                     effort: .normal, repeatFrequency: .daily),
        TemplateSpec(kind: .chore, titleJa: "お米を炊く", titleEn: "Cook rice",
                     effort: .light, repeatFrequency: .daily),
        TemplateSpec(kind: .chore, titleJa: "掃除機をかける", titleEn: "Vacuum the floor",
                     effort: .normal, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "トイレ掃除", titleEn: "Clean the toilet",
                     effort: .light, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "お風呂掃除", titleEn: "Clean the bathroom",
                     effort: .normal, repeatFrequency: .daily),
        TemplateSpec(kind: .chore, titleJa: "キッチン掃除", titleEn: "Clean the kitchen",
                     effort: .normal, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "洗濯", titleEn: "Do the laundry",
                     effort: .normal, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "洗濯物をたたむ", titleEn: "Fold the laundry",
                     effort: .light, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "ゴミ出し", titleEn: "Take out the trash",
                     effort: .light, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "食器洗い", titleEn: "Wash the dishes",
                     effort: .light, repeatFrequency: .daily),
        TemplateSpec(kind: .chore, titleJa: "排水口掃除", titleEn: "Clean the drain",
                     effort: .normal, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "シーツ交換", titleEn: "Change the sheets",
                     effort: .light, repeatFrequency: .monthly),
        TemplateSpec(kind: .chore, titleJa: "部屋の片付け", titleEn: "Tidy up the room",
                     effort: .light, repeatFrequency: .weekly),
        TemplateSpec(kind: .chore, titleJa: "買い物メモの確認", titleEn: "Check the shopping list",
                     effort: .light, repeatFrequency: .weekly),
    ]

    private static let commonGroceries: [TemplateSpec] = [
        TemplateSpec(kind: .grocery, titleJa: "トイレットペーパー", titleEn: "Toilet paper", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "ティッシュ", titleEn: "Tissues", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "洗濯洗剤", titleEn: "Laundry detergent", category: .cleaning),
        TemplateSpec(kind: .grocery, titleJa: "食器用洗剤", titleEn: "Dish soap", category: .cleaning),
        TemplateSpec(kind: .grocery, titleJa: "シャンプー", titleEn: "Shampoo", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "ボディソープ", titleEn: "Body soap", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "歯磨き粉", titleEn: "Toothpaste", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "ゴミ袋", titleEn: "Trash bags", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "キッチンペーパー", titleEn: "Paper towels", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "ラップ", titleEn: "Plastic wrap", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "アルミホイル", titleEn: "Aluminum foil", category: .household),
        TemplateSpec(kind: .grocery, titleJa: "ハンドソープ", titleEn: "Hand soap", category: .cleaning),
        TemplateSpec(kind: .grocery, titleJa: "掃除用シート", titleEn: "Cleaning wipes", category: .cleaning),
        TemplateSpec(kind: .grocery, titleJa: "スポンジ", titleEn: "Sponges", category: .cleaning),
        TemplateSpec(kind: .grocery, titleJa: "柔軟剤", titleEn: "Fabric softener", category: .cleaning),
    ]
}
