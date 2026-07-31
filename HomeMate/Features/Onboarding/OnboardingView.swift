//
//  OnboardingView.swift
//  HomeMate
//
//  初回オンボーディング（最大4画面）。
//  60秒以内にボード作成、長い説明は禁止、という設計方針に沿う。
//

import SwiftUI
import CoreData
import os

private let onboardingLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "onboarding")

@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome
        case audience
        case createBoard
        case chores
        case groceries
    }

    var step: Step = .welcome
    var audience: HomeType = .family
    var homeName: String = ""
    var displayName: String = ""
    var cloudStatus: CloudAccountStatus?

    // おすすめ家事の複数選択。
    var choreOptions: [TemplateSpec] = []
    var selectedChoreIds: Set<UUID> = []

    // 今日の買い物ヒアリング。
    var grocerySuggestions: [TemplateSpec] = []
    var selectedGroceryIds: Set<UUID> = []
    var customGroceries: [String] = []
    var groceryDraft: String = ""

    /// 端末ロケールから ja / en を決める。
    var locale: String {
        Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
    }

    var canCreateBoard: Bool {
        !homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var showLocalModeNote: Bool {
        guard let cloudStatus else { return false }
        return !cloudStatus.canShare
    }

    /// 家事・買い物候補を一度だけ用意する（家事は既定未選択。ユーザーが選んだものだけ追加）。
    func prepareTemplates() {
        if choreOptions.isEmpty {
            choreOptions = TemplateProvider.starterChores(for: audience)
        }
        if grocerySuggestions.isEmpty {
            grocerySuggestions = TemplateProvider.starterGroceries(for: audience)
        }
    }

    var selectedChoreSpecs: [TemplateSpec] {
        choreOptions.filter { selectedChoreIds.contains($0.id) }
    }

    var groceryNames: [String] {
        let suggested = grocerySuggestions
            .filter { selectedGroceryIds.contains($0.id) }
            .map { $0.title(for: locale) }
        return suggested + customGroceries
    }

    func toggleChore(_ spec: TemplateSpec) {
        if selectedChoreIds.contains(spec.id) {
            selectedChoreIds.remove(spec.id)
        } else {
            selectedChoreIds.insert(spec.id)
        }
    }

    func toggleGrocerySuggestion(_ spec: TemplateSpec) {
        if selectedGroceryIds.contains(spec.id) {
            selectedGroceryIds.remove(spec.id)
        } else {
            selectedGroceryIds.insert(spec.id)
        }
    }

    func commitGroceryDraft() {
        let name = groceryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !customGroceries.contains(name) {
            customGroceries.append(name)
        }
        groceryDraft = ""
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.managedObjectContext) private var viewContext
    @State private var model = OnboardingModel()
    @State private var showCreationError = false
    private let cloudAccountService = CloudAccountService()

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, HMSpacing.m)

            GeometryReader { proxy in
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .id(model.step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))

            footer
        }
        .background(HMColor.background)
        .task {
            appState.analytics.track(.onboardingStarted)
            let status = await cloudAccountService.currentStatus()
            model.cloudStatus = status
            appState.analytics.track(.icloudStatusChecked,
                                     parameters: ["can_share": status.canShare])
        }
        .alert("onboarding.createFailed.title", isPresented: $showCreationError) {
            Button("common.done", role: .cancel) {}
        } message: {
            Text("onboarding.createFailed.message")
        }
    }

    private var progressDots: some View {
        HStack(spacing: HMSpacing.s) {
            ForEach(OnboardingModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= model.step.rawValue ? HMColor.accent : HMColor.surface)
                    .frame(width: step == model.step ? 22 : 7, height: 7)
                    .animation(HMMotion.spring, value: model.step)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            WelcomeStep()
        case .audience:
            AudienceStep(selection: $model.audience)
        case .createBoard:
            CreateBoardStep(homeName: $model.homeName,
                            displayName: $model.displayName,
                            showLocalModeNote: model.showLocalModeNote)
        case .chores:
            ChoreSelectStep(model: model)
        case .groceries:
            GroceryHearingStep(model: model)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: HMSpacing.s) {
            switch model.step {
            case .welcome:
                HMPrimaryButton(title: "onboarding.welcome.button") { advance() }
            case .audience:
                HMPrimaryButton(title: "common.next") { advance() }
            case .createBoard:
                HMPrimaryButton(title: "common.next", isEnabled: model.canCreateBoard) {
                    advance()
                }
            case .chores:
                HMPrimaryButton(title: "common.next") { advance() }
            case .groceries:
                HMPrimaryButton(title: "onboarding.start") {
                    finish()
                }
            }
        }
        .padding(HMSpacing.m)
    }

    private func advance() {
        guard let next = OnboardingModel.Step(rawValue: model.step.rawValue + 1) else { return }
        if next == .chores {
            model.prepareTemplates()
        }
        withAnimation(HMMotion.smooth) { model.step = next }
    }

    private func finish() {
        let service = HomeService(context: viewContext)
        do {
            let home = try service.createHome(name: model.homeName,
                                              homeType: model.audience,
                                              currentMemberName: model.displayName,
                                              locale: model.locale)
            appState.analytics.track(.homeCreated, parameters: ["home_type": model.audience.rawValue])

            model.commitGroceryDraft()
            let choreSpecs = model.selectedChoreSpecs
            let groceryNames = model.groceryNames
            if !choreSpecs.isEmpty || !groceryNames.isEmpty {
                try service.addOnboardingStarters(to: home,
                                                  choreSpecs: choreSpecs,
                                                  groceryNames: groceryNames,
                                                  locale: model.locale)
                appState.analytics.track(.templateAdded,
                                         parameters: ["count": choreSpecs.count + groceryNames.count])
            }

            appState.analytics.track(.onboardingCompleted)
            appState.selectedHomeId = home.id
            // オンボ完了直後・チュートリアル開始前に通知許可を依頼する（オプトイン率向上）。
            _Concurrency.Task {
                if await NotificationService.shared.authorizationStatus() == .notDetermined {
                    _ = await NotificationService.shared.requestAuthorization()
                }
                await MainActor.run {
                    withAnimation { appState.hasCompletedOnboarding = true }
                }
            }
        } catch {
            // 作成に失敗してもクラッシュさせず、ユーザーに再試行を促す。
            onboardingLogger.error("ボード作成に失敗: \(error.localizedDescription, privacy: .private)")
            showCreationError = true
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    @State private var appeared = false

    private let features: [(symbol: String, key: LocalizedStringKey, tint: Color)] = [
        ("rectangle.stack.fill", "onboarding.feature.board", HMColor.accent),
        ("calendar", "onboarding.feature.calendar", HMColor.request),
        ("photo.fill", "onboarding.feature.photo", HMColor.grocery)
    ]

    var body: some View {
        VStack(spacing: HMSpacing.l) {
            Spacer(minLength: HMSpacing.l)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [HMColor.accent.opacity(0.22), HMColor.grocery.opacity(0.18)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 140, height: 140)
                Image(systemName: "house.lodge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(HMColor.accent)
                    .symbolEffect(.bounce, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: HMSpacing.s) {
                Text("onboarding.welcome.title")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("onboarding.welcome.body")
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, HMSpacing.l)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: HMSpacing.m) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: HMSpacing.m) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(feature.tint)
                            .frame(width: 40, height: 40)
                            .background(feature.tint.opacity(0.14))
                            .clipShape(Circle())
                        Text(feature.key)
                            .font(HMTypography.body)
                            .foregroundStyle(HMColor.primaryText)
                        Spacer(minLength: 0)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(HMMotion.spring.delay(0.15 + Double(index) * 0.08), value: appeared)
                }
            }
            .padding(HMSpacing.l)
            .background(HMColor.card)
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
            .hmShadow(.soft)
            .padding(.horizontal, HMSpacing.l)
            .padding(.top, HMSpacing.xs)

            Spacer(minLength: HMSpacing.l)
        }
        .padding()
        .onAppear {
            withAnimation(HMMotion.spring.delay(0.05)) { appeared = true }
        }
    }
}

private struct AudienceStep: View {
    @Binding var selection: HomeType

    private let options: [HomeType] = [.family, .couple, .roommates, .solo]

    var body: some View {
        VStack(alignment: .leading, spacing: HMSpacing.l) {
            Text("onboarding.audience.question")
                .font(.system(.title, design: .rounded).weight(.bold))
                .padding(.top, HMSpacing.xl)

            VStack(spacing: HMSpacing.s) {
                ForEach(options) { option in
                    Button {
                        HMHaptics.selection()
                        withAnimation(HMMotion.quick) { selection = option }
                    } label: {
                        HStack(spacing: HMSpacing.m) {
                            Image(systemName: option.onboardingSymbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selection == option ? .white : HMColor.accent)
                                .frame(width: 40, height: 40)
                                .background(selection == option ? HMColor.accent : HMColor.accent.opacity(0.14))
                                .clipShape(Circle())
                            Text(option.onboardingTitleKey)
                                .font(HMTypography.body)
                                .fontWeight(.medium)
                                .foregroundStyle(HMColor.primaryText)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HMColor.accent)
                            }
                        }
                        .padding(HMSpacing.m)
                        .background(HMColor.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                                .strokeBorder(selection == option ? HMColor.accent : .clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
                        .hmShadow(.soft)
                    }
                    .buttonStyle(HMPressableStyle(scale: 0.98))
                }
            }
            Spacer()
        }
        .padding(.horizontal, HMSpacing.m)
    }
}

private struct CreateBoardStep: View {
    @Binding var homeName: String
    @Binding var displayName: String
    let showLocalModeNote: Bool

    @State private var appeared = false
    @FocusState private var focusedField: Field?

    private enum Field { case home, display }

    var body: some View {
        VStack(spacing: HMSpacing.l) {
            header
                .padding(.top, HMSpacing.l)

            VStack(spacing: HMSpacing.m) {
                inputCard(icon: "house.fill",
                          tint: HMColor.accent,
                          label: "onboarding.create.homeName",
                          placeholder: "onboarding.create.homeName.placeholder",
                          text: $homeName,
                          field: .home,
                          submit: .next)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(HMMotion.spring.delay(0.12), value: appeared)

                inputCard(icon: "person.fill",
                          tint: HMColor.request,
                          label: "onboarding.create.displayName",
                          placeholder: "onboarding.create.displayName.placeholder",
                          text: $displayName,
                          field: .display,
                          submit: .done)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(HMMotion.spring.delay(0.2), value: appeared)
            }

            if showLocalModeNote {
                HMCard(style: .tinted(HMColor.grocery)) {
                    HStack(spacing: HMSpacing.s) {
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(HMColor.grocery)
                        Text("onboarding.icloud.localModeNote")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .animation(HMMotion.smooth.delay(0.28), value: appeared)
            }
            Spacer(minLength: HMSpacing.l)
        }
        .padding(.horizontal, HMSpacing.m)
        .onAppear {
            appeared = true
        }
    }

    private var header: some View {
        VStack(spacing: HMSpacing.m) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [HMColor.accent.opacity(0.22), HMColor.request.opacity(0.18)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 104, height: 104)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(HMColor.accent)
                    .symbolEffect(.bounce, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .animation(HMMotion.spring, value: appeared)

            VStack(spacing: HMSpacing.s) {
                Text("onboarding.create.title")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("onboarding.create.body")
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, HMSpacing.l)
            .opacity(appeared ? 1 : 0)
            .animation(HMMotion.smooth.delay(0.06), value: appeared)
        }
    }

    private func inputCard(icon: String,
                           tint: Color,
                           label: LocalizedStringKey,
                           placeholder: LocalizedStringKey,
                           text: Binding<String>,
                           field: Field,
                           submit: SubmitLabel) -> some View {
        let isFocused = focusedField == field
        return HStack(spacing: HMSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                TextField(placeholder, text: text)
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.primaryText)
                    .focused($focusedField, equals: field)
                    .submitLabel(submit)
            }
            Spacer(minLength: 0)
        }
        .padding(HMSpacing.m)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous)
                .strokeBorder(isFocused ? tint.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .hmShadow(.soft)
        .animation(HMMotion.quick, value: isFocused)
    }
}

private struct ChoreSelectStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: HMSpacing.l) {
            VStack(spacing: HMSpacing.s) {
                ZStack {
                    Circle()
                        .fill(HMColor.chore.opacity(0.16))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checklist")
                        .font(.system(size: 44))
                        .foregroundStyle(HMColor.chore)
                }
                Text("onboarding.chores.title")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("onboarding.chores.body")
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HMSpacing.l)
            .padding(.top, HMSpacing.l)

            SelectableChips(specs: model.choreOptions,
                            locale: model.locale,
                            tint: HMColor.chore,
                            isSelected: { model.selectedChoreIds.contains($0.id) },
                            onToggle: { model.toggleChore($0) })
                .padding(.horizontal, HMSpacing.l)

            Text("onboarding.chores.scheduleNote")
                .font(HMTypography.caption)
                .foregroundStyle(HMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HMSpacing.l)

            Spacer(minLength: HMSpacing.l)
        }
    }
}

private struct GroceryHearingStep: View {
    @Bindable var model: OnboardingModel
    @FocusState private var draftFocused: Bool

    var body: some View {
        VStack(spacing: HMSpacing.l) {
            VStack(spacing: HMSpacing.s) {
                ZStack {
                    Circle()
                        .fill(HMColor.grocery.opacity(0.16))
                        .frame(width: 96, height: 96)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(HMColor.grocery)
                }
                Text("onboarding.groceries.title")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("onboarding.groceries.body")
                    .font(HMTypography.body)
                    .foregroundStyle(HMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HMSpacing.l)
            .padding(.top, HMSpacing.l)

            if !model.grocerySuggestions.isEmpty {
                SelectableChips(specs: model.grocerySuggestions,
                                locale: model.locale,
                                tint: HMColor.grocery,
                                isSelected: { model.selectedGroceryIds.contains($0.id) },
                                onToggle: { model.toggleGrocerySuggestion($0) })
                    .padding(.horizontal, HMSpacing.l)
            }

            VStack(spacing: HMSpacing.s) {
                HStack(spacing: HMSpacing.s) {
                    TextField("onboarding.groceries.placeholder", text: $model.groceryDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($draftFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            model.commitGroceryDraft()
                            draftFocused = true
                        }
                    Button {
                        model.commitGroceryDraft()
                        draftFocused = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(HMColor.grocery)
                    }
                    .disabled(model.groceryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !model.customGroceries.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: HMSpacing.s)],
                              alignment: .leading, spacing: HMSpacing.s) {
                        ForEach(model.customGroceries, id: \.self) { name in
                            HStack(spacing: HMSpacing.xs) {
                                Text(name)
                                    .font(HMTypography.caption)
                                Button {
                                    model.customGroceries.removeAll { $0 == name }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, HMSpacing.m)
                            .padding(.vertical, HMSpacing.s)
                            .background(HMColor.grocery.opacity(0.16))
                            .foregroundStyle(HMColor.grocery)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, HMSpacing.l)

            Spacer(minLength: HMSpacing.l)
        }
    }
}

/// 折り返し表示する選択可能なチップ群。
private struct SelectableChips: View {
    let specs: [TemplateSpec]
    let locale: String
    let tint: Color
    let isSelected: (TemplateSpec) -> Bool
    let onToggle: (TemplateSpec) -> Void

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 96), spacing: HMSpacing.s)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: HMSpacing.s) {
            ForEach(specs) { spec in
                let selected = isSelected(spec)
                Button {
                    withAnimation(HMMotion.smooth) { onToggle(spec) }
                    HMHaptics.selection()
                } label: {
                    HStack(spacing: HMSpacing.xs) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text(spec.title(for: locale))
                            .font(HMTypography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, HMSpacing.m)
                    .padding(.vertical, HMSpacing.s)
                    .background(selected ? tint.opacity(0.18) : HMColor.surface)
                    .foregroundStyle(selected ? tint : HMColor.primaryText)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selected ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(HMPressableStyle(scale: 0.94))
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppState())
}
