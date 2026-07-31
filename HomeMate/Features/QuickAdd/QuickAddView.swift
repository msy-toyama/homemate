//
//  QuickAddView.swift
//  HomeMate
//
//  家事・買い物・お願いを素早く追加するボトムシート。
//  画面に応じた既定タイプで開く。買い物は連続追加に最適化する（設計 15章）。
//

import SwiftUI
import CoreData
import os

private let quickAddLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "quickadd")

struct QuickAddView: View {
    enum AddType: String, CaseIterable, Identifiable {
        case chore, grocery, request
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .chore: return "quickadd.type.chore"
            case .grocery: return "quickadd.type.grocery"
            case .request: return "quickadd.type.request"
            }
        }
        var systemImage: String {
            switch self {
            case .chore: return "checklist"
            case .grocery: return "cart"
            case .request: return "hand.raised"
            }
        }
    }

    let home: Home
    @State var type: AddType
    /// カレンダーから特定日付で追加する場合の初期期日。
    var presetDueDate: Date? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // 共通入力。
    @State private var title: String = ""
    @State private var assigneeId: UUID?
    /// タスク・お願いは「今日」を既定にする（任意で日付変更・繰り返し設定可）。
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    /// 既定は終日（時刻指定なし）。
    @State private var isAllDay: Bool = true
    /// 通知タイミング（期限の何分前か）。既定 1 時間前。
    @State private var notificationOffsetMinutes: Int16 = NotificationLeadTime.hour1.rawValue
    @State private var showSchedule = false
    /// シートの高さ。ハーフ（medium）では最小限、フル（large）では詳細項目を表示する。
    @State private var detent: PresentationDetent = .medium

    // 家事用。
    @State private var recurrence: RecurrenceRule = .none
    @State private var rotation: RotationPolicy = .fixed
    @State private var effort: EffortLevel = .normal
    @State private var visibility: TaskVisibility = .shared
    @State private var notes: String = ""

    // 買い物用。
    @State private var category: GroceryCategory?
    @State private var quantity: String = ""
    @State private var recentlyAdded: [String] = []

    @FocusState private var titleFocused: Bool

    private var members: [Member] { home.membersArray }
    private var currentMember: Member? { home.currentMember }

    /// シートが展開されている（詳細表示）か。
    private var isDetailed: Bool { detent == .large }

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if type == .request, assigneeId == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: HMSpacing.s) {
                        ForEach(AddType.allCases) { t in
                            HMChip(title: t.titleKey,
                                   systemImage: t.systemImage,
                                   tint: tint(for: t),
                                   isSelected: type == t) {
                                withAnimation(HMMotion.smooth) { type = t }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(titlePlaceholder, text: $title)
                        .font(HMTypography.body)
                        .focused($titleFocused)
                        .submitLabel(type == .grocery ? .next : .done)
                        .onSubmit {
                            if type == .grocery { addGroceryAndContinue() }
                        }
                }

                switch type {
                case .chore:
                    choreFields
                case .grocery:
                    groceryFields
                case .request:
                    requestFields
                }
            }
            .navigationTitle("quickadd.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.add") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                assigneeId = currentMember?.id
                titleFocused = true
                if let presetDueDate {
                    hasDueDate = true
                    dueDate = presetDueDate
                }
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleEditorView(hasDueDate: $hasDueDate,
                                   dueDate: $dueDate,
                                   recurrence: $recurrence,
                                   isAllDay: $isAllDay,
                                   notificationOffsetMinutes: $notificationOffsetMinutes,
                                   allowRecurrence: type == .chore || type == .grocery)
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .animation(HMMotion.spring, value: detent)
    }

    private func tint(for type: AddType) -> Color {
        switch type {
        case .chore: return HMColor.chore
        case .grocery: return HMColor.grocery
        case .request: return HMColor.request
        }
    }

    // MARK: - Fields

    @ViewBuilder private var choreFields: some View {
        Section("quickadd.assignee") {
            assigneePicker(allowAnyone: true)
        }
        Section {
            HMNavRow(title: "schedule.title",
                     systemImage: "calendar",
                     value: choreScheduleSummary,
                     tint: HMColor.chore) {
                showSchedule = true
            }
            if recurrence.isRepeating, members.count > 1 {
                Picker("quickadd.rotation", selection: $rotation) {
                    ForEach(RotationPolicy.allCases) { policy in
                        Text(policy.titleKey).tag(policy)
                    }
                }
            }
        }
        if isDetailed {
            Section {
                Picker("quickadd.visibility", selection: $visibility) {
                    ForEach(TaskVisibility.allCases) { v in
                        Label(v.titleKey, systemImage: v.symbolName).tag(v)
                    }
                }
            } footer: {
                if visibility == .private {
                    Text("taskdetail.visibility.private.note")
                }
            }
            Section("quickadd.effort") {
                Picker("quickadd.effort", selection: $effort) {
                    ForEach(EffortLevel.allCases) { level in
                        Text(level.titleKey).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("quickadd.notes") {
                TextField("quickadd.notes.placeholder", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        } else {
            expandHintRow
        }
    }

    /// ハーフシート時に「上に広げると詳細を設定できる」と伝えるアフォーダンス。
    private var expandHintRow: some View {
        Button {
            withAnimation(HMMotion.smooth) { detent = .large }
        } label: {
            HStack(spacing: HMSpacing.m) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HMColor.accent)
                    .frame(width: 36, height: 36)
                    .background(HMColor.accent.opacity(0.14))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("quickadd.expand.hint")
                        .font(HMTypography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(HMColor.primaryText)
                    Text("quickadd.expand.hint.sub")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HMColor.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var choreScheduleSummary: String {
        var parts: [String] = []
        if hasDueDate {
            parts.append(relativeDueLabel(dueDate))
        }
        if recurrence.isRepeating {
            parts.append(recurrence.summary(locale: LanguageManager.activeLocale))
        }
        return parts.isEmpty ? LanguageManager.localized("schedule.none") : parts.joined(separator: " · ")
    }

    /// 期限を「今日 HH:mm」「明日 HH:mm」または絶対日付で表示する。終日は時刻を省略。
    private func relativeDueLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let dayPart: String
        if cal.isDateInToday(date) {
            dayPart = LanguageManager.localized("common.today")
        } else if cal.isDateInTomorrow(date) {
            dayPart = LanguageManager.localized("common.tomorrow")
        } else {
            dayPart = date.formatted(Date.FormatStyle(date: .abbreviated).locale(LanguageManager.activeLocale))
        }
        if isAllDay {
            return dayPart + " · " + LanguageManager.localized("schedule.allDay")
        }
        let time = date.formatted(Date.FormatStyle(time: .shortened).locale(LanguageManager.activeLocale))
        return dayPart + " " + time
    }

    @ViewBuilder private var groceryFields: some View {
        Section {
            HMNavRow(title: "schedule.title",
                     systemImage: "calendar",
                     value: choreScheduleSummary,
                     tint: HMColor.grocery) {
                showSchedule = true
            }
        }
        Section("quickadd.category") {
            Picker("quickadd.category", selection: $category) {
                Text("quickadd.category.none").tag(GroceryCategory?.none)
                ForEach(GroceryCategory.allCases) { cat in
                    Text(cat.titleKey).tag(GroceryCategory?.some(cat))
                }
            }
        }
        Section("quickadd.quantity") {
            QuantityField(text: $quantity)
        }
        if !recentlyAdded.isEmpty {
            Section("quickadd.recentlyAdded") {
                ForEach(recentlyAdded, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(HMColor.success)
                }
            }
        }
    }

    @ViewBuilder private var requestFields: some View {
        Section("quickadd.requestTo") {
            assigneePicker(allowAnyone: false)
        }
        Section {
            HMNavRow(title: "schedule.title",
                     systemImage: "calendar",
                     value: hasDueDate ? relativeDueLabel(dueDate) : LanguageManager.localized("schedule.none"),
                     tint: HMColor.request) {
                showSchedule = true
            }
        }
        Section {
            Text("quickadd.request.note")
                .font(.footnote)
                .foregroundStyle(HMColor.secondaryText)
        }
    }

    @ViewBuilder private func assigneePicker(allowAnyone: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HMSpacing.s) {
                if allowAnyone {
                    assigneeOption(member: nil, isSelected: assigneeId == nil) {
                        assigneeId = nil
                    }
                }
                ForEach(members, id: \.objectID) { member in
                    assigneeOption(member: member, isSelected: assigneeId == member.id) {
                        assigneeId = member.id
                    }
                }
            }
            .padding(.vertical, HMSpacing.xs)
        }
        .listRowInsets(EdgeInsets(top: HMSpacing.s, leading: HMSpacing.m,
                                  bottom: HMSpacing.s, trailing: HMSpacing.m))
    }

    @ViewBuilder private func assigneeOption(member: Member?,
                                             isSelected: Bool,
                                             action: @escaping () -> Void) -> some View {
        Button {
            HMHaptics.selection()
            action()
        } label: {
            HStack(spacing: HMSpacing.s) {
                if let member {
                    MemberBadge(member: member, size: 26, showsRing: false)
                    Text(member.resolvedDisplayName)
                } else {
                    Image(systemName: "person.2")
                        .foregroundStyle(HMColor.accent)
                    Text("quickadd.assignee.anyone")
                }
            }
            .font(HMTypography.callout)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? Color.white : HMColor.primaryText)
            .padding(.horizontal, HMSpacing.m)
            .padding(.vertical, HMSpacing.s)
            .background(isSelected ? HMColor.accent : HMColor.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(HMPressableStyle())
    }

    private var titlePlaceholder: LocalizedStringKey {
        switch type {
        case .chore: return "quickadd.title.chore"
        case .grocery: return "quickadd.title.grocery"
        case .request: return "quickadd.title.request"
        }
    }

    // MARK: - Actions

    private func save() {
        switch type {
        case .chore:
            saveChore()
        case .grocery:
            addGroceryAndContinue()
            dismiss()
        case .request:
            saveRequest()
        }
    }

    private func saveChore() {
        let service = TaskService(context: viewContext)
        let assignee = home.member(withID: assigneeId)
        guard HMErrorReporter.attempt("家事を追加", logger: quickAddLogger, {
            try service.create(in: home,
                            title: title,
                            type: .chore,
                            assignedTo: assignee,
                            dueAt: hasDueDate ? dueDate : nil,
                            isAllDay: isAllDay,
                            recurrence: recurrence,
                            rotation: rotation,
                            effort: effort,
                            visibility: visibility,
                            notificationOffsetMinutes: hasDueDate ? notificationOffsetMinutes : NotificationLeadTime.off.rawValue,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                            by: currentMember)
        }) else { return }
        appState.analytics.track(.taskCreated)
        if recurrence.isRepeating {
            appState.analytics.track(.recurringTaskCreated)
        }
        dismiss()
    }

    private func saveRequest() {
        let service = RequestService(context: viewContext)
        let assignee = home.member(withID: assigneeId)
        guard HMErrorReporter.attempt("お願いを追加", logger: quickAddLogger, {
            try service.create(in: home,
                           title: title,
                           assignedTo: assignee,
                           dueAt: hasDueDate ? dueDate : nil,
                           isAllDay: isAllDay,
                           by: currentMember)
        }) else { return }
        appState.analytics.track(.requestCreated)
        dismiss()
    }

    /// 買い物を1件追加し、入力欄を空にしてキーボードを維持（連続追加）。
    private func addGroceryAndContinue() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let service = GroceryService(context: viewContext)
        guard HMErrorReporter.attempt("買い物を追加", logger: quickAddLogger, {
            try service.add(in: home,
                        name: trimmed,
                        category: category,
                        quantity: quantity.isEmpty ? nil : quantity,
                        dueAt: hasDueDate ? dueDate : nil,
                        isAllDay: isAllDay,
                        recurrence: recurrence,
                        by: currentMember)
        }) else { return }
        appState.analytics.track(.groceryCreated)
        recentlyAdded.insert(trimmed, at: 0)
        HMHaptics.impact(.light)
        title = ""
        quantity = ""
        titleFocused = true
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let home = (try? context.fetch(Home.fetchRequest()).first) ?? Home(context: context)
    return QuickAddView(home: home, type: .chore)
        .environment(\.managedObjectContext, context)
        .environment(AppState())
}
