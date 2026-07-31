//
//  ListsView.swift
//  HomeMate
//
//  家事・買い物・お願いの一覧。買い物は画面内で連続追加できる（設計 14・15章）。
//

import SwiftUI
import CoreData
import os

private let listsLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "lists")

struct ListsView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case chores, groceries, requests
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .chores: return "lists.segment.chores"
            case .groceries: return "lists.segment.groceries"
            case .requests: return "lists.segment.requests"
            }
        }
    }

    /// 一覧の表示モード（行リスト／2列タイル）。
    enum ViewMode: String {
        case list, grid
    }

    let home: Home

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState

    @FetchRequest private var tasks: FetchedResults<Task>
    @FetchRequest private var groceries: FetchedResults<GroceryItem>

    @Binding private var segment: Segment
    @Binding private var showCompleted: Bool
    @AppStorage("lists.viewMode") private var viewMode: ViewMode = .list
    @State private var quickGroceryName = ""
    @State private var quickChoreName = ""
    @State private var quickRequestName = ""
    @State private var thanksTarget: ThanksTarget?
    @State private var editTarget: TaskEditTarget?
    @State private var groceryTarget: GroceryEditTarget?
    @State private var undoToken: UndoToken?
    @FocusState private var groceryFieldFocused: Bool
    @FocusState private var choreFieldFocused: Bool
    @FocusState private var requestFieldFocused: Bool

    struct ThanksTarget: Identifiable {
        let id = UUID()
        let recipient: Member
        let targetType: MentalLoadTargetType
        let targetId: UUID?
    }

    init(home: Home,
         segment: Binding<Segment> = .constant(.chores),
         showCompleted: Binding<Bool> = .constant(false)) {
        self.home = home
        _segment = segment
        _showCompleted = showCompleted
        _tasks = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueAt, ascending: true),
                              NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)],
            predicate: BoardView.taskPredicate(for: home),
            animation: .default)
        _groceries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \GroceryItem.createdAt, ascending: false)],
            predicate: NSPredicate(format: "home == %@ AND archivedAt == nil", home),
            animation: .default)
    }

    private var chores: [Task] {
        tasks.filter { $0.taskTypeValue != .request }
            .filter { showCompleted ? true : $0.taskStatusValue == .active }
    }
    private var requests: [Task] {
        tasks.filter { $0.taskTypeValue == .request }
            .filter { showCompleted ? true : $0.taskStatusValue == .active }
    }
    private var groceryItems: [GroceryItem] {
        groceries.filter { showCompleted ? true : $0.statusValue == .active }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("lists.segment", selection: $segment) {
                    ForEach(Segment.allCases) { seg in
                        Text(seg.titleKey).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(HMSpacing.m)

                content
                    .transition(.opacity)
                    .animation(HMMotion.smooth, value: segment)
            }
            .background(HMColor.background)
            .undoToast($undoToken, onUndo: undoComplete)
            .navigationTitle("tab.lists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(HMMotion.smooth) {
                            viewMode = viewMode == .list ? .grid : .list
                        }
                        HMHaptics.selection()
                    } label: {
                        Label(viewMode == .list ? "lists.viewMode.grid" : "lists.viewMode.list",
                              systemImage: viewMode == .list ? "square.grid.2x2.fill" : "list.bullet")
                    }
                    .tint(HMColor.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showCompleted) {
                        Label("lists.showCompleted", systemImage: showCompleted ? "eye" : "eye.slash")
                    }
                    .toggleStyle(.button)
                    .font(HMTypography.caption)
                    .tint(HMColor.accent)
                }
            }
            .sheet(item: $thanksTarget) { target in
                ThanksSheet(home: home,
                            recipient: target.recipient,
                            targetType: target.targetType,
                            targetId: target.targetId)
            }
            .sheet(item: $editTarget) { target in
                TaskDetailView(task: target.task, home: home)
            }
            .sheet(item: $groceryTarget) { target in
                GroceryDetailView(item: target.item)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch segment {
        case .chores:
            taskList(chores, empty: "lists.chores.empty", tint: HMColor.chore,
                     addText: $quickChoreName, addFocus: $choreFieldFocused,
                     addPlaceholder: "lists.chore.add.placeholder", onAdd: addChore)
        case .groceries:
            groceryList
        case .requests:
            taskList(requests, empty: "lists.requests.empty", tint: HMColor.request,
                     addText: $quickRequestName, addFocus: $requestFieldFocused,
                     addPlaceholder: "lists.request.add.placeholder", onAdd: addRequest)
        }
    }

    /// 一覧上部の連続追加入力欄（家事・お願い・買い物で共通）。
    private func inlineAddField(text: Binding<String>,
                                focus: FocusState<Bool>.Binding,
                                placeholder: LocalizedStringKey,
                                tint: Color,
                                onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: HMSpacing.s) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(tint)
            TextField(placeholder, text: text)
                .font(HMTypography.body)
                .focused(focus)
                .submitLabel(.next)
                .onSubmit(onSubmit)
        }
        .padding(HMSpacing.m)
        .background(HMColor.card)
        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
        .hmShadow(.soft)
        .padding(.horizontal, HMSpacing.m)
        .padding(.bottom, HMSpacing.s)
    }

    private func taskList(_ items: [Task], empty: LocalizedStringKey, tint: Color,
                          addText: Binding<String>, addFocus: FocusState<Bool>.Binding,
                          addPlaceholder: LocalizedStringKey, onAdd: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            inlineAddField(text: addText, focus: addFocus,
                           placeholder: addPlaceholder, tint: tint, onSubmit: onAdd)
            taskListBody(items, empty: empty, tint: tint, onAddFocus: { addFocus.wrappedValue = true })
        }
    }

    private func taskListBody(_ items: [Task], empty: LocalizedStringKey, tint: Color,
                             onAddFocus: @escaping () -> Void) -> some View {
        Group {
            if items.isEmpty {
                HMEmptyState(systemImage: "tray.fill", title: empty,
                             message: "lists.empty.message", tint: tint,
                             actionTitle: "board.empty.add",
                             action: onAddFocus)
                    .padding()
                Spacer()
            } else if viewMode == .grid {
                taskGridView(items)
            } else {
                taskRowsView(items)
            }
        }
    }

    /// 行リスト表示（1列カード）。ボードと同じ ScrollView+VStack 方式で行が縦に間延びしないようにする。
    /// スワイプ操作は List 専用のため、操作は長押しのコンテキストメニューで代替する。
    private func taskRowsView(_ items: [Task]) -> some View {
        ScrollView {
            LazyVStack(spacing: HMSpacing.m) {
                ForEach(items, id: \.objectID) { task in
                    TaskRow(task: task, home: home, onComplete: { complete(task) },
                            onOpen: { editTarget = TaskEditTarget(task: task) })
                        .padding(.horizontal, HMSpacing.m)
                        .background(HMColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
                        .hmShadow(.soft)
                        .contextMenu { taskContextMenu(task) }
                }
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.m)
        }
        .scrollContentBackground(.hidden)
    }

    /// 2列タイル表示（スワイプ非対応のため操作はコンテキストメニュー）。
    private func taskGridView(_ items: [Task]) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HMSpacing.m),
                                GridItem(.flexible(), spacing: HMSpacing.m)],
                      spacing: HMSpacing.m) {
                ForEach(items, id: \.objectID) { task in
                    TaskTile(task: task, home: home, onComplete: { complete(task) },
                             onOpen: { editTarget = TaskEditTarget(task: task) })
                        .contextMenu { taskContextMenu(task) }
                }
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.m)
        }
        .scrollContentBackground(.hidden)
    }

    /// タスク行/タイル共通のコンテキストメニュー。
    @ViewBuilder
    private func taskContextMenu(_ task: Task) -> some View {
        if task.isCompleted {
            Button {
                reactivate(task)
            } label: {
                Label("row.reactivate", systemImage: "arrow.uturn.backward")
            }
        } else if let target = thanksTargetIfPossible(for: task) {
            Button {
                thanksTarget = target
            } label: {
                Label("thanks.action", systemImage: "heart")
            }
        }
        Button {
            editTarget = TaskEditTarget(task: task)
        } label: {
            Label("row.edit", systemImage: "pencil")
        }
        Button {
            duplicate(task)
        } label: {
            Label("row.duplicate", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            deleteTask(task)
        } label: {
            Label("row.delete", systemImage: "trash")
        }
    }

    private var groceryList: some View {
        VStack(spacing: 0) {
            // 連続追加用の入力欄。Enter で追加してフォーカスを維持する。
            HStack(spacing: HMSpacing.s) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(HMColor.grocery)
                TextField("lists.grocery.add.placeholder", text: $quickGroceryName)
                    .font(HMTypography.body)
                    .focused($groceryFieldFocused)
                    .submitLabel(.next)
                    .onSubmit(addGrocery)
            }
            .padding(HMSpacing.m)
            .background(HMColor.card)
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
            .hmShadow(.soft)
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.s)

            if groceryItems.isEmpty {
                HMEmptyState(systemImage: "cart.fill",
                             title: "lists.groceries.empty",
                             message: "lists.empty.message",
                             tint: HMColor.grocery,
                             actionTitle: "board.empty.add",
                             action: { groceryFieldFocused = true })
                    .padding()
                Spacer()
            } else if viewMode == .grid {
                groceryGridView
            } else {
                groceryRowsView
            }
        }
    }

    /// 買い物の行リスト表示（1列カード）。タスク行と同じ ScrollView+VStack 方式で統一する。
    private var groceryRowsView: some View {
        ScrollView {
            LazyVStack(spacing: HMSpacing.m) {
                ForEach(groceryItems, id: \.objectID) { item in
                    GroceryRow(item: item, onToggle: { toggleGrocery(item) },
                               onOpen: { groceryTarget = GroceryEditTarget(item: item) })
                        .padding(.horizontal, HMSpacing.m)
                        .background(HMColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: HMRadius.card, style: .continuous))
                        .hmShadow(.soft)
                        .contextMenu { groceryContextMenu(item) }
                }
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.m)
        }
        .scrollContentBackground(.hidden)
    }

    /// 買い物の2列タイル表示。
    private var groceryGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HMSpacing.m),
                                GridItem(.flexible(), spacing: HMSpacing.m)],
                      spacing: HMSpacing.m) {
                ForEach(groceryItems, id: \.objectID) { item in
                    GroceryTile(item: item, onToggle: { toggleGrocery(item) },
                                onOpen: { groceryTarget = GroceryEditTarget(item: item) })
                        .contextMenu { groceryContextMenu(item) }
                }
            }
            .padding(.horizontal, HMSpacing.m)
            .padding(.bottom, HMSpacing.m)
        }
        .scrollContentBackground(.hidden)
    }

    /// 買い物の共通コンテキストメニュー。
    @ViewBuilder
    private func groceryContextMenu(_ item: GroceryItem) -> some View {
        Button {
            groceryTarget = GroceryEditTarget(item: item)
        } label: {
            Label("row.edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
            deleteGrocery(item)
        } label: {
            Label("row.delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    /// 完了済みで、完了者が自分以外のメンバーなら「ありがとう」対象を返す。
    private func thanksTargetIfPossible(for task: Task) -> ThanksTarget? {
        guard task.taskStatusValue == .completed,
              let doerId = task.completedByMemberId,
              doerId != home.currentMember?.id,
              let doer = home.member(withID: doerId) else {
            return nil
        }
        return ThanksTarget(recipient: doer,
                            targetType: task.taskTypeValue == .request ? .request : .task,
                            targetId: task.id)
    }

    private func addGrocery() {
        let trimmed = quickGroceryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let service = GroceryService(context: viewContext)
        HMErrorReporter.attempt("買い物を追加", logger: listsLogger) {
            try service.add(in: home, name: trimmed, by: home.currentMember)
        }
        appState.analytics.track(.groceryCreated)
        HMHaptics.impact(.light)
        quickGroceryName = ""
        groceryFieldFocused = true
    }

    /// 既定の「今日」期限（終日）。即追加でも今日のタスクとして登録する。
    private func defaultDueToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// 自分以外の最初のメンバー（お願いの既定の宛先）。単独利用時は nil。
    private func otherMember() -> Member? {
        home.membersArray.first { $0.id != home.currentMember?.id }
    }

    private func addChore() {
        let trimmed = quickChoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let service = TaskService(context: viewContext)
        HMErrorReporter.attempt("家事を追加", logger: listsLogger) {
            try service.create(in: home,
                                title: trimmed,
                                type: .chore,
                                assignedTo: nil,
                                dueAt: defaultDueToday(),
                                isAllDay: true,
                                by: home.currentMember)
        }
        appState.analytics.track(.taskCreated)
        HMHaptics.impact(.light)
        quickChoreName = ""
        choreFieldFocused = true
    }

    private func addRequest() {
        let trimmed = quickRequestName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let service = RequestService(context: viewContext)
        let assignee = otherMember() ?? home.currentMember
        HMErrorReporter.attempt("お願いを追加", logger: listsLogger) {
            try service.create(in: home,
                                title: trimmed,
                                assignedTo: assignee,
                                dueAt: defaultDueToday(),
                                isAllDay: true,
                                by: home.currentMember)
        }
        appState.analytics.track(.requestCreated)
        HMHaptics.impact(.light)
        quickRequestName = ""
        requestFieldFocused = true
    }

    private func complete(_ task: Task) {
        let service = TaskService(context: viewContext)
        if task.taskStatusValue == .active {
            do {
                let result = try service.complete(task, by: home.currentMember)
                appState.analytics.track(task.taskTypeValue == .request ? .requestCompleted : .taskCompleted)
                undoToken = UndoToken(completedID: result.completedTask.objectID,
                                      generatedID: result.generatedTask?.objectID)
            } catch {
                // 失敗を握りつぶすと「完了したのに残る」ように見えるため、明示的に通知＋記録する。
                HMHaptics.error()
                listsLogger.error("タスク完了に失敗: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    private func reactivate(_ task: Task) {
        let service = TaskService(context: viewContext)
        let generated = service.generatedNextOccurrence(of: task)
        HMErrorReporter.attempt("タスクを未完了に戻す", logger: listsLogger) {
            try service.reactivate(task, removingGenerated: generated)
        }
        HMHaptics.selection()
    }

    private func undoComplete(_ token: UndoToken) {
        let service = TaskService(context: viewContext)
        guard let task = try? viewContext.existingObject(with: token.completedID) as? Task else { return }
        let generated = token.generatedID.flatMap { try? viewContext.existingObject(with: $0) as? Task }
        HMErrorReporter.attempt("完了の取り消し", logger: listsLogger) {
            try service.reactivate(task, removingGenerated: generated)
        }
    }

    private func duplicate(_ task: Task) {
        let service = TaskService(context: viewContext)
        HMErrorReporter.attempt("タスクを複製", logger: listsLogger) {
            try service.create(in: home,
                                title: task.resolvedTitle,
                                type: task.taskTypeValue,
                                assignedTo: home.member(withID: task.assignedToMemberId),
                                dueAt: task.dueAt,
                                recurrence: task.recurrenceRule,
                                rotation: task.rotationPolicyValue,
                                effort: task.effortLevelValue,
                                visibility: task.visibilityValue,
                                notes: task.notes,
                                by: home.currentMember)
        }
        appState.analytics.track(.taskCreated)
        if task.recurrenceRule.isRepeating {
            appState.analytics.track(.recurringTaskCreated)
        }
        HMHaptics.impact(.light)
    }

    private func deleteTask(_ task: Task) {
        let service = TaskService(context: viewContext)
        HMErrorReporter.attempt("タスクを削除", logger: listsLogger) {
            try service.archive(task)
        }
        HMHaptics.impact(.medium)
    }

    private func toggleGrocery(_ item: GroceryItem) {
        let service = GroceryService(context: viewContext)
        if item.isCompleted {
            HMErrorReporter.attempt("買い物を未完了に戻す", logger: listsLogger) {
                try service.reactivate(item)
            }
        } else {
            guard HMErrorReporter.attempt("買い物完了", logger: listsLogger, {
                try service.complete(item, by: home.currentMember)
            }) else { return }
            appState.analytics.track(.groceryCompleted)
        }
    }

    private func deleteGrocery(_ item: GroceryItem) {
        let service = GroceryService(context: viewContext)
        HMErrorReporter.attempt("買い物を削除", logger: listsLogger) {
            try service.archive(item)
        }
        HMHaptics.impact(.medium)
    }
}
