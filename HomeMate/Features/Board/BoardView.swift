//
//  BoardView.swift
//  HomeMate
//
//  ホームの「今日」を一目で把握するボード画面（設計 13章）。
//  今日のサマリー → 次にやること → 今日のタスク → 買い物プレビュー → お願い。
//

import SwiftUI
import CoreData
import StoreKit
import os

private let boardLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "board")

struct BoardView: View {
    let home: Home
    var onOpenList: ((ListsView.Segment) -> Void)?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.requestReview) private var requestReview

    @FetchRequest private var tasks: FetchedResults<Task>
    @FetchRequest private var groceries: FetchedResults<GroceryItem>

    @State private var showQuickAdd = false
    @State private var quickAddType: QuickAddView.AddType = .chore
    @State private var showSettings = false
    @State private var showMembers = false
    @State private var showBoardSwitcher = false
    @State private var editTarget: TaskEditTarget?
    @State private var groceryTarget: GroceryEditTarget?
    @State private var undoToken: UndoToken?
    @State private var progressScope: ProgressScope = .today
    @State private var showInsights = false
    @State private var showInsightsPaywall = false

    /// 進捗リングの集計対象。「今日やるべき分」か「期限なしを含む全体」を切り替える。
    enum ProgressScope: String, CaseIterable, Identifiable {
        case today, all
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            self == .today ? "board.progress.scope.today" : "board.progress.scope.all"
        }
    }

    init(home: Home, onOpenList: ((ListsView.Segment) -> Void)? = nil) {
        self.home = home
        self.onOpenList = onOpenList
        _tasks = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)],
            predicate: Self.taskPredicate(for: home),
            animation: .default)
        _groceries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \GroceryItem.createdAt, ascending: false)],
            predicate: NSPredicate(format: "home == %@ AND archivedAt == nil", home),
            animation: .default)
    }

    /// 自分視点の可視タスク。共有タスクと、自分が作成したプライベートタスクのみ。
    static func taskPredicate(for home: Home) -> NSPredicate {
        var format = "home == %@ AND archivedAt == nil"
        var args: [Any] = [home]
        if let meId = home.currentMember?.id {
            format += " AND (visibility == %@ OR visibility == nil OR createdByMemberId == %@)"
            args.append("shared")
            args.append(meId as NSUUID)
        } else {
            format += " AND (visibility == %@ OR visibility == nil)"
            args.append("shared")
        }
        return NSPredicate(format: format, argumentArray: args)
    }

    private var activeChores: [Task] {
        tasks.filter { $0.taskTypeValue != .request && $0.taskStatusValue == .active }
    }
    private var activeRequests: [Task] {
        tasks.filter { $0.taskTypeValue == .request && $0.taskStatusValue == .active }
    }
    private var activeGroceries: [GroceryItem] {
        groceries.filter { $0.statusValue == .active }
    }
    private var completedTodayChores: [Task] {
        let cal = Calendar.current
        return tasks.filter { task in
            task.taskTypeValue != .request && task.taskStatusValue == .completed
                && (task.completedAt.map { cal.isDateInToday($0) } ?? false)
        }
    }
    private var completedTodayGroceries: [GroceryItem] {
        let cal = Calendar.current
        return groceries.filter { item in
            item.statusValue == .completed
                && (item.completedAt.map { cal.isDateInToday($0) } ?? false)
        }
    }
    private var completedTodayRequests: [Task] {
        let cal = Calendar.current
        return tasks.filter { task in
            task.taskTypeValue == .request && task.taskStatusValue == .completed
                && (task.completedAt.map { cal.isDateInToday($0) } ?? false)
        }
    }
    private var todayTotalCount: Int { activeChores.count + completedTodayChores.count }

    /// 今日の家事ボードに表示する家事：今日期限・期限切れ・期限なしのみ（未来予定は除外）。
    private var todaySectionChores: [Task] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return activeChores.filter { task in
            guard let due = task.dueAt else { return true }
            return cal.isDateInToday(due) || cal.startOfDay(for: due) < startOfToday
        }
    }

    /// 今日期限・期限切れの未完了家事（「今日やるべき分」の未完了）。
    private var todayDueChores: [Task] {
        let cal = Calendar.current
        return activeChores.filter { task in
            guard let due = task.dueAt else { return false }
            return cal.isDateInToday(due) || due < Date()
        }
    }
    /// 今日期限・期限切れ・期限なしの未完了買い物。
    private var todayDueGroceries: [GroceryItem] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        return activeGroceries.filter { item in
            guard let due = item.dueAt else { return true }
            return cal.isDateInToday(due) || cal.startOfDay(for: due) < startOfToday
        }
    }
    /// 今日完了した家事・買い物の合計。
    private var completedTodayCount: Int { completedTodayChores.count + completedTodayGroceries.count }
    /// 今日の達成率の母数＝今日対応すべき未完了（家事＋買い物）＋今日完了した分。
    private var todayDenominator: Int { todayDueChores.count + todayDueGroceries.count + completedTodayCount }
    private var todayProgress: Double {
        guard todayDenominator > 0 else { return 1 }
        return Double(completedTodayCount) / Double(todayDenominator)
    }
    /// 期限なしも含む全アクティブ（家事＋買い物）の達成率。
    private var allDenominator: Int { activeChores.count + activeGroceries.count + completedTodayCount }
    private var allProgress: Double {
        guard allDenominator > 0 else { return 1 }
        return Double(completedTodayCount) / Double(allDenominator)
    }
    /// 選択中の集計対象に応じた表示値。
    private var shownProgress: Double { progressScope == .today ? todayProgress : allProgress }
    private var shownTotal: Int { progressScope == .today ? todayDenominator : allDenominator }
    private var shownDone: Int { completedTodayCount }
    private var nextUpItem: NextUpResolver.Item? {
        NextUpResolver.resolveItem(tasks: Array(tasks),
                                   groceries: Array(groceries),
                                   currentMemberId: home.currentMember?.id)
    }
    private var reflection: WeeklyReflection {
        WeeklyReflectionResolver.reflect(for: home)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HMSpacing.m) {
                    if !home.isShared && home.homeTypeValue != .solo {
                        inviteBanner
                    }
                    progressHeader
                    summaryCard
                    if let nextUpItem {
                        switch nextUpItem {
                        case .task(let task):
                            nextUpCard(task)
                        case .groceries(let items):
                            nextUpGroceriesCard(items)
                        }
                    }
                    todaySection
                    grocerySection
                    if !activeRequests.isEmpty {
                        requestSection
                    }
                    if reflection.shouldShow {
                        WeeklyReflectionView(reflection: reflection) {
                            if entitlementStore.isUnlocked(.contributionInsights, for: home) {
                                showInsights = true
                            } else {
                                showInsightsPaywall = true
                            }
                        }
                        .onAppear { appState.analytics.track(.weeklyReflectionViewed) }
                    }
                }
                .padding(.horizontal, HMSpacing.m)
                .padding(.top, 60)
                .padding(.bottom, HMSpacing.m)
            }
            .background(HMColor.background)
            .undoToast($undoToken, onUndo: undoComplete)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                boardTopBar
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(home: home, type: quickAddType)
            }
            .sheet(isPresented: $showBoardSwitcher) {
                BoardSwitcherView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(home: home)
            }
            .sheet(item: $editTarget) { target in
                TaskDetailView(task: target.task, home: home)
            }
            .sheet(item: $groceryTarget) { target in
                GroceryDetailView(item: target.item)
            }
            .sheet(isPresented: $showInsights) {
                ContributionInsightsView(home: home)
            }
            .sheet(isPresented: $showInsightsPaywall) {
                PaywallView(context: .insights)
            }
        }
    }

    // MARK: - Sections

    private var boardTopBar: some View {
        ZStack {
            Button {
                showBoardSwitcher = true
            } label: {
                HStack(spacing: HMSpacing.xs) {
                    Circle()
                        .fill(home.colorTokenValue.color)
                        .frame(width: 10, height: 10)
                    Text(home.displayName)
                        .font(HMTypography.heading)
                        .foregroundStyle(HMColor.primaryText)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HMColor.secondaryText)
                }
                .padding(.horizontal, HMSpacing.m)
                .padding(.vertical, HMSpacing.s)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }
            .accessibilityLabel("boards.switcher.accessibility")
            .coachmarkAnchor(.boardSwitcher)

            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(HMColor.primaryText)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                }
                .accessibilityLabel("settings.title")
                .coachmarkAnchor(.settings)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, HMSpacing.m)
        .padding(.vertical, HMSpacing.xs)
    }

    private var inviteBanner: some View {
        Button {
            showMembers = true
        } label: {
            HMCard(style: .tinted(HMColor.accent)) {
                HStack(spacing: HMSpacing.m) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(HMColor.accent)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("board.invite.title")
                            .font(HMTypography.heading)
                            .foregroundStyle(HMColor.primaryText)
                        Text("board.invite.message")
                            .font(HMTypography.caption)
                            .foregroundStyle(HMColor.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HMColor.accent)
                }
            }
        }
        .buttonStyle(HMPressableStyle(scale: 0.98))
        .sheet(isPresented: $showMembers) {
            NavigationStack {
                MembersView(home: home)
            }
        }
    }

    private var progressHeader: some View {
        let done = shownDone
        let total = shownTotal
        let allDone = total > 0 && done == total
        return HMCard(style: .tinted(allDone ? HMColor.success : HMColor.accent)) {
            VStack(alignment: .leading, spacing: HMSpacing.s) {
                HStack(spacing: HMSpacing.m) {
                    HMProgressRing(progress: shownProgress,
                                   size: 64,
                                   tint: allDone ? HMColor.success : HMColor.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(allDone ? "board.progress.done.title" : "board.progress.title")
                            .font(HMTypography.heading)
                            .foregroundStyle(HMColor.primaryText)
                        if total > 0 {
                            Text(LanguageManager.localized("board.progress.fraction", done, total))
                                .font(HMTypography.caption)
                                .foregroundStyle(HMColor.secondaryText)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text(progressScope == .today ? "board.progress.empty" : "board.progress.empty.all")
                                .font(HMTypography.caption)
                                .foregroundStyle(HMColor.secondaryText)
                        }
                    }
                    Spacer()
                    if allDone {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(HMColor.success)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Picker("board.progress.scope", selection: $progressScope) {
                    ForEach(ProgressScope.allCases) { scope in
                        Text(scope.titleKey).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .animation(HMMotion.smooth, value: shownProgress)
        .accessibilityElement(children: .combine)
    }

    private var summaryCard: some View {
        HStack(spacing: HMSpacing.m) {
            StatTile(count: activeChores.count, titleKey: "board.summary.chores",
                     systemImage: "checklist", tint: HMColor.chore,
                     sublabel: "board.summary.sub.incomplete",
                     doneToday: completedTodayChores.count,
                     action: { onOpenList?(.chores) })
            StatTile(count: activeGroceries.count, titleKey: "board.summary.groceries",
                     systemImage: "cart.fill", tint: HMColor.grocery,
                     sublabel: "board.summary.sub.remaining",
                     doneToday: completedTodayGroceries.count,
                     action: { onOpenList?(.groceries) })
            StatTile(count: activeRequests.count, titleKey: "board.summary.requests",
                     systemImage: "hand.raised.fill", tint: HMColor.request,
                     sublabel: "board.summary.sub.unconfirmed",
                     doneToday: completedTodayRequests.count,
                     action: { onOpenList?(.requests) })
        }
    }

    private func nextUpCard(_ task: Task) -> some View {
        HMCard(style: .tinted(HMColor.accent)) {
            VStack(alignment: .leading, spacing: HMSpacing.s) {
                HStack(spacing: HMSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                    Text("board.nextUp")
                        .font(HMTypography.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(HMColor.accent)
                TaskRow(task: task, home: home, onComplete: { complete(task) },
                        onOpen: { editTarget = TaskEditTarget(task: task) })
            }
        }
    }

    /// 未完了の買い物がある場合に「次にやること」として表示するカード。
    private func nextUpGroceriesCard(_ items: [GroceryItem]) -> some View {
        let names = items.prefix(3).map { $0.name ?? "" }.filter { !$0.isEmpty }
        let preview = names.joined(separator: "、")
        return Button {
            HMHaptics.selection()
            onOpenList?(.groceries)
        } label: {
            HMCard(style: .tinted(HMColor.grocery)) {
                VStack(alignment: .leading, spacing: HMSpacing.s) {
                    HStack(spacing: HMSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.caption.bold())
                        Text("board.nextUp")
                            .font(HMTypography.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(HMColor.grocery)
                    HStack(spacing: HMSpacing.s) {
                        Image(systemName: "cart.fill")
                            .font(.title3)
                            .foregroundStyle(HMColor.grocery)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("board.nextUp.groceries.title")
                                .font(HMTypography.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(HMColor.primaryText)
                            if !preview.isEmpty {
                                (items.count > 3
                                 ? Text("board.nextUp.groceries.detail.more \(preview)")
                                 : Text(verbatim: preview))
                                    .font(HMTypography.caption)
                                    .foregroundStyle(HMColor.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(HMColor.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(HMPressableStyle(scale: 0.98))
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            sectionHeader("board.today", count: todaySectionChores.count,
                          tint: HMColor.chore,
                          showSeeAll: todaySectionChores.count > 5,
                          segment: .chores)
            if todaySectionChores.isEmpty {
                HMCard {
                    HMEmptyState(systemImage: "checkmark.seal.fill",
                                 title: "board.today.empty.title",
                                 message: "board.today.empty.message",
                                 tint: HMColor.chore,
                                 actionTitle: "board.empty.add",
                                 action: { presentQuickAdd(.chore) })
                }
            } else {
                HMCard {
                    VStack(spacing: 0) {
                        ForEach(Array(todaySectionChores.prefix(5)), id: \.objectID) { task in
                            TaskRow(task: task, home: home, onComplete: { complete(task) },
                                    onOpen: { editTarget = TaskEditTarget(task: task) })
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("row.delete", systemImage: "trash")
                                    }
                                }
                            if task.objectID != todaySectionChores.prefix(5).last?.objectID {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var grocerySection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            sectionHeader("board.groceries", count: activeGroceries.count,
                          tint: HMColor.grocery,
                          showSeeAll: activeGroceries.count > 5,
                          segment: .groceries)
            if activeGroceries.isEmpty {
                HMCard {
                    HMEmptyState(systemImage: "cart.fill",
                                 title: "board.groceries.empty.title",
                                 message: "board.groceries.empty.message",
                                 tint: HMColor.grocery,
                                 actionTitle: "board.empty.add",
                                 action: { presentQuickAdd(.grocery) })
                }
            } else {
                HMCard {
                    VStack(spacing: 0) {
                        ForEach(Array(activeGroceries.prefix(5)), id: \.objectID) { item in
                            GroceryRow(item: item, onToggle: { toggleGrocery(item) },
                                       onOpen: { groceryTarget = GroceryEditTarget(item: item) })
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteGrocery(item)
                                    } label: {
                                        Label("row.delete", systemImage: "trash")
                                    }
                                }
                            if item.objectID != activeGroceries.prefix(5).last?.objectID {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            sectionHeader("board.requests", count: activeRequests.count,
                          tint: HMColor.request,
                          showSeeAll: activeRequests.count > 5,
                          segment: .requests)
            HMCard {
                VStack(spacing: 0) {
                    ForEach(activeRequests, id: \.objectID) { request in
                        TaskRow(task: request, home: home, onComplete: { complete(request) },
                                onOpen: { editTarget = TaskEditTarget(task: request) })
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteTask(request)
                                } label: {
                                    Label("row.delete", systemImage: "trash")
                                }
                            }
                        if request.objectID != activeRequests.last?.objectID {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey,
                               count: Int,
                               tint: Color,
                               showSeeAll: Bool,
                               segment: ListsView.Segment? = nil) -> some View {
        HStack(spacing: HMSpacing.s) {
            Text(key)
                .font(HMTypography.heading)
            if count > 0 {
                HMCountBadge(count: count, tint: tint)
            }
            Spacer()
            if showSeeAll, let segment, let onOpenList {
                Button {
                    HMHaptics.selection()
                    onOpenList(segment)
                } label: {
                    Text("board.seeAll")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentQuickAdd(_ type: QuickAddView.AddType) {
        quickAddType = type
        showQuickAdd = true
    }

    private var addButton: some View {
        Button {
            presentQuickAdd(.chore)
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(colors: [HMColor.accent, HMColor.accentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .hmShadow(.floating)
        }
        .buttonStyle(HMPressableStyle(scale: 0.92))
        .padding(HMSpacing.l)
        .accessibilityLabel("quickadd.title")
        .coachmarkAnchor(.fab)
    }

    // MARK: - Actions

    private func complete(_ task: Task) {
        let service = TaskService(context: viewContext)
        guard let result = HMErrorReporter.attemptValue("タスク完了", logger: boardLogger, {
            try service.complete(task, by: home.currentMember)
        }) else { return }
        appState.analytics.track(task.taskTypeValue == .request ? .requestCompleted : .taskCompleted)
        undoToken = UndoToken(completedID: result.completedTask.objectID,
                              generatedID: result.generatedTask?.objectID)
        if ReviewPrompt.shouldRequestReviewAfterCompletion() {
            requestReview()
        }
    }

    private func undoComplete(_ token: UndoToken) {
        let service = TaskService(context: viewContext)
        guard let task = try? viewContext.existingObject(with: token.completedID) as? Task else { return }
        let generated = token.generatedID.flatMap { try? viewContext.existingObject(with: $0) as? Task }
        HMErrorReporter.attempt("完了の取り消し", logger: boardLogger) {
            try service.reactivate(task, removingGenerated: generated)
        }
    }

    private func toggleGrocery(_ item: GroceryItem) {
        let service = GroceryService(context: viewContext)
        if item.isCompleted {
            HMErrorReporter.attempt("買い物を未完了に戻す", logger: boardLogger) {
                try service.reactivate(item)
            }
        } else {
            guard HMErrorReporter.attempt("買い物完了", logger: boardLogger, {
                try service.complete(item, by: home.currentMember)
            }) else { return }
            appState.analytics.track(.groceryCompleted)
        }
    }

    private func deleteTask(_ task: Task) {
        let service = TaskService(context: viewContext)
        HMErrorReporter.attempt("タスクを削除", logger: boardLogger) {
            try service.archive(task)
        }
        HMHaptics.impact(.medium)
    }

    private func deleteGrocery(_ item: GroceryItem) {
        let service = GroceryService(context: viewContext)
        HMErrorReporter.attempt("買い物を削除", logger: boardLogger) {
            try service.archive(item)
        }
        HMHaptics.impact(.medium)
    }
}
