//
//  CoachmarkOverlay.swift
//  HomeMate
//
//  初回チュートリアル。実画面の上に暗幕＋スポットライト＋吹き出しを重ね、
//  主要な操作（ボード切替・タブ・追加・設定）を順番に案内する。設定から再生も可能。
//

import SwiftUI

/// チュートリアルでスポットライトを当てる実ビューを識別するキー。
/// 実際のボタン位置を anchorPreference で取得し、スポットライトのずれを防ぐ。
enum CoachmarkTarget: Hashable {
    case boardSwitcher
    case settings
    case fab
}

/// 各ターゲットの実フレームを親ビューまで伝搬する PreferenceKey。
struct CoachmarkAnchorKey: PreferenceKey {
    static let defaultValue: [CoachmarkTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachmarkTarget: Anchor<CGRect>],
                       nextValue: () -> [CoachmarkTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// このビューの実フレームをチュートリアルのスポットライト対象として登録する。
    func coachmarkAnchor(_ target: CoachmarkTarget) -> some View {
        anchorPreference(key: CoachmarkAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

/// スポットライトを当てる画面上の領域。ジオメトリから矩形を導出する。
enum CoachmarkSpotlight {
    case none
    case topCenter      // ボードスイッチャー（上部中央）
    case topTrailing    // 設定ギア（右上）
    case bottomBar      // タブバー（下部）
    case fab            // 追加ボタン（右下）

    /// セーフエリアを考慮した実寸の矩形を返す。標準的な iOS のナビゲーションバー/タブバーは寸法に合わせる。
    func rect(in size: CGSize, safeArea: EdgeInsets) -> CGRect? {
        // インラインナビゲーションバーの高さは約 44pt。その中心 Y。
        let navBarHeight: CGFloat = 44
        let navCenterY = safeArea.top + navBarHeight / 2
        switch self {
        case .none:
            return nil
        case .topCenter:
            let width: CGFloat = min(240, size.width - 120)
            return CGRect(x: (size.width - width) / 2, y: navCenterY - 18, width: width, height: 36)
        case .topTrailing:
            let d: CGFloat = 44
            let x = size.width - safeArea.trailing - 16 - d
            return CGRect(x: x, y: navCenterY - d / 2, width: d, height: d)
        case .bottomBar:
            // 標準タブバー高さ約 49pt。ホームインジケータ（下部セーフエリア）は含めないが、
            // タブバー本体だけだと窮屈に見えるため上下に対称の余白を足す。
            // 中心はタブバー中央のまま保つ（下にずれない）。
            let tabBarHeight: CGFloat = 49
            let verticalPadding: CGFloat = HMSpacing.s
            let y = size.height - safeArea.bottom - tabBarHeight - verticalPadding
            return CGRect(x: 8, y: y,
                          width: size.width - 16,
                          height: tabBarHeight + verticalPadding * 2)
        case .fab:
            // 実フレームが取れないときのフォールバック。FAB は 60pt、タブバーの上に padding(l=24)。
            let d: CGFloat = 68
            let fabSize: CGFloat = 60
            let padding: CGFloat = HMSpacing.l
            let tabBarHeight: CGFloat = 49
            let centerX = size.width - safeArea.trailing - padding - fabSize / 2
            let centerY = size.height - safeArea.bottom - tabBarHeight - padding - fabSize / 2
            return CGRect(x: centerX - d / 2, y: centerY - d / 2, width: d, height: d)
        }
    }
}

struct CoachmarkStep: Identifiable {
    let id = UUID()
    let spotlight: CoachmarkSpotlight
    let icon: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
}

extension CoachmarkStep {
    /// 標準のメインツアー。
    static let mainTour: [CoachmarkStep] = [
        CoachmarkStep(spotlight: .none,
                      icon: "hand.wave.fill",
                      title: "tour.welcome.title",
                      body: "tour.welcome.body"),
        CoachmarkStep(spotlight: .topCenter,
                      icon: "rectangle.stack.fill",
                      title: "tour.boards.title",
                      body: "tour.boards.body"),
        CoachmarkStep(spotlight: .bottomBar,
                      icon: "square.grid.2x2.fill",
                      title: "tour.tabs.title",
                      body: "tour.tabs.body"),
        CoachmarkStep(spotlight: .fab,
                      icon: "plus.circle.fill",
                      title: "tour.add.title",
                      body: "tour.add.body"),
        CoachmarkStep(spotlight: .topTrailing,
                      icon: "gearshape.fill",
                      title: "tour.settings.title",
                      body: "tour.settings.body")
    ]
}

struct CoachmarkOverlay: View {
    let steps: [CoachmarkStep]
    /// スポットライト対象の生アンカー。解決と描画を同じ GeometryReader（同一座標空間）で
    /// 行うことで、セーフエリア分のずれを防ぐ。
    var anchors: [CoachmarkTarget: Anchor<CGRect>] = [:]
    /// 実画面のセーフエリア。本ビューは .ignoresSafeArea() を使うため内部の
    /// proxy.safeAreaInsets はゼロになる。タブバー等の計算用に実寸を外部から受け取る。
    var hostSafeArea: EdgeInsets = EdgeInsets()
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var appeared = false

    private var step: CoachmarkStep { steps[min(index, steps.count - 1)] }
    private var isLast: Bool { index >= steps.count - 1 }

    /// ステップのスポットライト矩形。実フレームがあればジオメトリ推定より優先する。
    private func spotRect(in size: CGSize,
                         safeArea: EdgeInsets,
                         resolved: [CoachmarkTarget: CGRect]) -> CGRect? {
        switch step.spotlight {
        case .topCenter:
            if let real = resolved[.boardSwitcher] {
                return real.insetBy(dx: -8, dy: -6)
            }
        case .topTrailing:
            if let real = resolved[.settings] {
                return real.insetBy(dx: -6, dy: -6)
            }
        case .fab:
            if let real = resolved[.fab] {
                return real.insetBy(dx: -6, dy: -6)
            }
        case .none, .bottomBar:
            break
        }
        return step.spotlight.rect(in: size, safeArea: safeArea)
    }

    var body: some View {
        GeometryReader { proxy in
            // proxy は .ignoresSafeArea() 配下のため safeAreaInsets がゼロになる。
            // タブバー等のスポットライト計算には外部から渡された実セーフエリアを使う。
            let safeArea = hostSafeArea
            let size = proxy.size
            // 解決と描画を同じ proxy で行うことで座標空間を一致させる。
            let resolved = anchors.compactMapValues { proxy[$0] }
            let spot = spotRect(in: size, safeArea: safeArea, resolved: resolved)

            ZStack {
                dimmed(spot: spot)
                    .onTapGesture { advance() }

                if let spot {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .frame(width: spot.width + 8, height: spot.height + 8)
                        .position(x: spot.midX, y: spot.midY)
                        .allowsHitTesting(false)
                }

                tooltip
                    .frame(maxWidth: 360)
                    .padding(.horizontal, HMSpacing.l)
                    .position(tooltipPosition(spot: spot, size: size, safeArea: safeArea))
            }
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.25)) { appeared = true }
            }
        }
    }

    // MARK: - Pieces

    private func dimmed(spot: CGRect?) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.58))
            .reverseMask {
                if let spot {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .frame(width: spot.width + 8, height: spot.height + 8)
                        .position(x: spot.midX, y: spot.midY)
                }
            }
    }

    private var tooltip: some View {
        VStack(alignment: .leading, spacing: HMSpacing.m) {
            HStack(spacing: HMSpacing.s) {
                Image(systemName: step.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(HMColor.accent)
                    .clipShape(Circle())
                Text(step.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(HMColor.primaryText)
                Spacer()
            }

            Text(step.body)
                .font(HMTypography.body)
                .foregroundStyle(HMColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: HMSpacing.s) {
                Button("tour.skip") { finish() }
                    .font(HMTypography.callout)
                    .foregroundStyle(HMColor.secondaryText)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        Circle()
                            .fill(i == index ? HMColor.accent : HMColor.accent.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)

                Spacer()

                Button(isLast ? "tour.done" : "common.next") { advance() }
                    .font(HMTypography.callout.weight(.bold))
                    .foregroundStyle(HMColor.accent)
            }
        }
        .padding(HMSpacing.l)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.large, style: .continuous))
        .hmShadow(.floating)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Layout

    private func tooltipPosition(spot: CGRect?, size: CGSize, safeArea: EdgeInsets) -> CGPoint {
        let centerX = size.width / 2
        guard let spot else {
            return CGPoint(x: centerX, y: size.height / 2)
        }
        let estimatedHeight: CGFloat = 200
        // スポットライトが上半分なら下に、下半分なら上に吹き出しを置く。
        if spot.midY < size.height / 2 {
            let y = min(spot.maxY + estimatedHeight / 2 + 24,
                        size.height - safeArea.bottom - estimatedHeight / 2)
            return CGPoint(x: centerX, y: y)
        } else {
            let y = max(spot.minY - estimatedHeight / 2 - 24,
                        safeArea.top + estimatedHeight / 2)
            return CGPoint(x: centerX, y: y)
        }
    }

    // MARK: - Actions

    private func advance() {
        if isLast {
            finish()
        } else {
            HMHaptics.selection()
            if reduceMotion {
                index += 1
            } else {
                withAnimation(HMMotion.smooth) { index += 1 }
            }
        }
    }

    private func finish() {
        HMHaptics.impact(.light)
        onFinish()
    }
}

// MARK: - Reverse mask helper

private extension View {
    /// 指定した形でくり抜く（スポットライト用）。
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
