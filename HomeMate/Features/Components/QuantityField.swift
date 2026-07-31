//
//  QuantityField.swift
//  HomeMate
//
//  買い物の数量入力。自由入力のテキストフィールドに加え、
//  個数（1〜10）と単位（個・本・袋…）をドロップダウンから素早く選べる。
//

import SwiftUI

struct QuantityField: View {
    @Binding var text: String
    var placeholderKey: LocalizedStringKey = "quickadd.quantity.placeholder"

    @State private var count: String = ""
    @State private var unit: String = ""
    /// 11以上などプリセットに無い数を自由入力するモード。
    @State private var customCount = false
    @FocusState private var customFocused: Bool

    private static let presetCounts = Array(1...10)

    /// 単位の候補。表示はローカライズキー、値は選択時に挿入する文字列。
    private struct Unit: Identifiable {
        let id: String
        let key: LocalizedStringKey
        var label: String { LanguageManager.localized(id) }
    }

    private static let units: [Unit] = [
        Unit(id: "quantity.unit.piece", key: "quantity.unit.piece"),
        Unit(id: "quantity.unit.bottle", key: "quantity.unit.bottle"),
        Unit(id: "quantity.unit.bag", key: "quantity.unit.bag"),
        Unit(id: "quantity.unit.pack", key: "quantity.unit.pack"),
        Unit(id: "quantity.unit.box", key: "quantity.unit.box"),
        Unit(id: "quantity.unit.gram", key: "quantity.unit.gram"),
        Unit(id: "quantity.unit.kilogram", key: "quantity.unit.kilogram"),
        Unit(id: "quantity.unit.milliliter", key: "quantity.unit.milliliter"),
        Unit(id: "quantity.unit.liter", key: "quantity.unit.liter")
    ]

    var body: some View {
        HStack(spacing: HMSpacing.s) {
            countControl
            unitControl
            Spacer(minLength: 0)
        }
        .onAppear(perform: load)
    }

    // MARK: - 数

    @ViewBuilder private var countControl: some View {
        if customCount {
            HStack(spacing: HMSpacing.xs) {
                TextField("quantity.count.placeholder", text: $count)
                    .keyboardType(.numberPad)
                    .font(HMTypography.callout)
                    .frame(maxWidth: 70)
                    .focused($customFocused)
                    .onChange(of: count) { _, _ in compose() }
                Button {
                    customCount = false
                    count = ""
                    compose()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HMColor.secondaryText)
                }
            }
            .padding(.horizontal, HMSpacing.s)
            .padding(.vertical, 6)
            .background(HMColor.surface)
            .clipShape(Capsule())
        } else {
            Menu {
                ForEach(Self.presetCounts, id: \.self) { n in
                    Button("\(n)") {
                        count = "\(n)"
                        compose()
                        HMHaptics.selection()
                    }
                }
                Divider()
                Button("quantity.count.more") {
                    customCount = true
                    count = ""
                    customFocused = true
                    compose()
                }
            } label: {
                menuLabel(count.isEmpty ? LanguageManager.localized("quantity.count") : count)
            }
            .accessibilityLabel("quantity.count")
        }
    }

    // MARK: - 単位

    private var unitControl: some View {
        Menu {
            Button("quantity.unit.none") {
                unit = ""
                compose()
                HMHaptics.selection()
            }
            ForEach(Self.units) { u in
                Button(u.key) {
                    unit = u.label
                    compose()
                    HMHaptics.selection()
                }
            }
        } label: {
            menuLabel(unit.isEmpty ? LanguageManager.localized("quantity.unit") : unit)
        }
        .accessibilityLabel("quantity.unit")
    }

    private func menuLabel(_ value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
        }
        .font(HMTypography.callout)
        .foregroundStyle(HMColor.accent)
        .padding(.horizontal, HMSpacing.m)
        .padding(.vertical, 8)
        .background(HMColor.surface)
        .clipShape(Capsule())
    }

    // MARK: - 合成・初期化

    /// count と unit を結合して text に反映する。
    private func compose() {
        let n = count.filter(\.isNumber)
        if n != count { count = n }
        text = n + unit
    }

    /// 既存の text を数字部分と単位部分に分解して初期状態を作る。
    private func load() {
        let parts = split(text)
        count = parts.number
        unit = parts.unit
        if let n = Int(parts.number), !(1...10).contains(n) {
            customCount = true
        }
    }

    /// 入力文字列を先頭の数字部分と残りの単位部分に分解する。
    private func split(_ value: String) -> (number: String, unit: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let number = trimmed.prefix { $0.isNumber }
        let unit = trimmed.dropFirst(number.count).trimmingCharacters(in: .whitespaces)
        return (String(number), unit)
    }
}
