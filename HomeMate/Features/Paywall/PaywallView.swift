//
//  PaywallView.swift
//  HomeMate
//
//  おうちボード プラスのソフトペイウォール。
//  やさしいトーンで価値を伝え、年額（7日無料・デフォルト）／月額／買い切りを提示する。
//  「1人の購入で世帯全員」を明示し、復元・規約・プライバシーへの導線を備える（審査必須）。
//

import SwiftUI
import StoreKit

/// Paywall を出したきっかけ。見出しの出し分けと計測に使う。
enum PaywallContext: String {
    case multiBoard
    case insights
    case themes
    case general

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .multiBoard: return "paywall.subtitle.multiBoard"
        case .insights: return "paywall.subtitle.insights"
        case .themes: return "paywall.subtitle.themes"
        case .general: return "paywall.subtitle.general"
        }
    }
}

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(StoreService.self) private var store
    @Environment(AppState.self) private var appState

    @State private var selectedProductId = AppConfig.PlusProduct.yearly
    @State private var isWorking = false
    @State private var showError = false

    private let features: [PaywallFeature] = [
        .init(icon: "square.stack.3d.up.fill",
              title: "paywall.feature.multiBoard.title",
              desc: "paywall.feature.multiBoard.desc"),
        .init(icon: "chart.bar.doc.horizontal.fill",
              title: "paywall.feature.insights.title",
              desc: "paywall.feature.insights.desc"),
        .init(icon: "paintpalette.fill",
              title: "paywall.feature.themes.title",
              desc: "paywall.feature.themes.desc")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HMSpacing.l) {
                    header
                    featureList
                    if store.isPlusActive {
                        activeCard
                    } else {
                        planSection
                        cta
                        legalLinks
                    }
                }
                .padding(HMSpacing.m)
            }
            .background(HMColor.background)
            .navigationTitle("paywall.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("paywall.close") { dismissPaywall() }
                }
                if !store.isPlusActive {
                    ToolbarItem(placement: .primaryAction) {
                        Button("paywall.restore") { restore() }
                            .disabled(isWorking)
                    }
                }
            }
            .alert("paywall.error.title", isPresented: $showError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text("paywall.error.message")
            }
        }
        .onAppear {
            appState.analytics.track(.paywallShown, parameters: ["context": context.rawValue])
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: HMSpacing.s) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(HMColor.accent)
            Text("paywall.title")
                .font(HMTypography.title)
                .fontWeight(.bold)
            Text(context.subtitleKey)
                .font(HMTypography.body)
                .foregroundStyle(HMColor.secondaryText)
                .multilineTextAlignment(.center)
            Label("paywall.household", systemImage: "house.fill")
                .font(HMTypography.caption)
                .foregroundStyle(HMColor.success)
                .padding(.top, HMSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HMSpacing.s)
    }

    private var featureList: some View {
        HMCard {
            VStack(alignment: .leading, spacing: HMSpacing.m) {
                ForEach(features) { feature in
                    HStack(alignment: .top, spacing: HMSpacing.m) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HMColor.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(HMTypography.body)
                                .fontWeight(.semibold)
                            Text(feature.desc)
                                .font(HMTypography.caption)
                                .foregroundStyle(HMColor.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var activeCard: some View {
        HMCard(style: .tinted(HMColor.success)) {
            VStack(spacing: HMSpacing.s) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(HMColor.success)
                Text("paywall.active.title")
                    .font(HMTypography.body)
                    .fontWeight(.semibold)
                Text("paywall.active.message")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var planSection: some View {
        if store.isLoadingProducts && store.products.isEmpty {
            ProgressView()
                .padding(HMSpacing.l)
        } else if store.products.isEmpty {
            VStack(spacing: HMSpacing.s) {
                Text("paywall.loadFailed")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
                HMSecondaryButton(title: "common.retry", systemImage: "arrow.clockwise") {
                    _Concurrency.Task { await store.loadProducts() }
                }
            }
        } else {
            VStack(spacing: HMSpacing.s) {
                ForEach(store.products, id: \.id) { product in
                    PaywallPlanCard(
                        product: product,
                        isSelected: product.id == selectedProductId,
                        hasFreeTrial: store.hasFreeTrial(product)
                    ) {
                        selectedProductId = product.id
                    }
                }
            }
        }
    }

    private var cta: some View {
        HMPrimaryButton(title: ctaTitle, systemImage: isWorking ? nil : "sparkles", isEnabled: canPurchase) {
            purchase()
        }
        .overlay {
            if isWorking {
                ProgressView().tint(.white)
            }
        }
    }

    private var legalLinks: some View {
        VStack(spacing: HMSpacing.xs) {
            HStack(spacing: HMSpacing.m) {
                Button("paywall.terms") { openURL(AppConfig.Legal.termsURL) }
                Text("・").foregroundStyle(HMColor.tertiaryText)
                Button("paywall.privacy") { openURL(AppConfig.Legal.privacyURL) }
            }
            .font(HMTypography.caption)
            .foregroundStyle(HMColor.secondaryText)
            Text("paywall.legal.note")
                .font(HMTypography.caption2)
                .foregroundStyle(HMColor.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, HMSpacing.xs)
    }

    // MARK: - Derived

    private var selectedProduct: Product? {
        store.product(for: selectedProductId)
    }

    private var canPurchase: Bool {
        !isWorking && selectedProduct != nil
    }

    private var ctaTitle: LocalizedStringKey {
        guard let product = selectedProduct else { return "paywall.cta.buy" }
        if product.id == AppConfig.PlusProduct.lifetime {
            return "paywall.cta.buyLifetime"
        }
        return store.hasFreeTrial(product) ? "paywall.cta.trial" : "paywall.cta.buy"
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = selectedProduct else { return }
        isWorking = true
        appState.analytics.track(.purchaseStarted, parameters: ["product": product.id])
        _Concurrency.Task {
            defer { isWorking = false }
            do {
                let success = try await store.purchase(product)
                if success {
                    appState.analytics.track(.purchaseCompleted, parameters: ["product": product.id])
                    dismiss()
                }
            } catch {
                appState.analytics.track(.purchaseFailed, parameters: ["product": product.id])
                showError = true
            }
        }
    }

    private func restore() {
        isWorking = true
        _Concurrency.Task {
            defer { isWorking = false }
            do {
                try await store.restore()
                appState.analytics.track(.purchaseRestored)
                if store.isPlusActive { dismiss() }
            } catch {
                showError = true
            }
        }
    }

    private func dismissPaywall() {
        appState.analytics.track(.paywallDismissed, parameters: ["context": context.rawValue])
        dismiss()
    }
}

// MARK: - Feature row model

private struct PaywallFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: LocalizedStringKey
    let desc: LocalizedStringKey
}

// MARK: - Plan card

private struct PaywallPlanCard: View {
    let product: Product
    let isSelected: Bool
    let hasFreeTrial: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HMSpacing.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? HMColor.accent : HMColor.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: HMSpacing.s) {
                        Text(planTitle)
                            .font(HMTypography.body)
                            .fontWeight(.semibold)
                        if isBestValue {
                            Text("paywall.plan.bestValue")
                                .font(HMTypography.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(HMColor.accent.opacity(0.16))
                                .foregroundStyle(HMColor.accentDeep)
                                .clipShape(Capsule())
                        }
                    }
                    if hasFreeTrial {
                        Text("paywall.trialBadge")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.success)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: product.displayPrice)
                        .font(HMTypography.body)
                        .fontWeight(.semibold)
                    if let period = periodSuffix {
                        Text(period)
                            .font(HMTypography.caption2)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                }
            }
            .padding(HMSpacing.m)
            .background(HMColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? HMColor.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        }
        .buttonStyle(HMPressableStyle())
    }

    private var isBestValue: Bool {
        product.id == AppConfig.PlusProduct.yearly
    }

    private var planTitle: LocalizedStringKey {
        switch product.id {
        case AppConfig.PlusProduct.yearly: return "paywall.plan.yearly"
        case AppConfig.PlusProduct.monthly: return "paywall.plan.monthly"
        case AppConfig.PlusProduct.lifetime: return "paywall.plan.lifetime"
        default: return LocalizedStringKey(product.displayName)
        }
    }

    private var periodSuffix: LocalizedStringKey? {
        switch product.id {
        case AppConfig.PlusProduct.yearly: return "paywall.per.year"
        case AppConfig.PlusProduct.monthly: return "paywall.per.month"
        default: return nil
        }
    }
}
