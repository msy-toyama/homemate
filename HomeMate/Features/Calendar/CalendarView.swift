//
//  CalendarView.swift
//  HomeMate
//
//  月カレンダーで期日のあるタスク／お願いを一覧する。
//  日付タップでその日のアジェンダを表示し、その日付で追加もできる。
//

import SwiftUI
import CoreData
import os

private let calendarLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "calendar")

struct CalendarView: View {
    let home: Home

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AppState.self) private var appState

    @FetchRequest private var tasks: FetchedResults<Task>

    @State private var displayedMonth: Date = CalendarView.monthStart(Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editTarget: TaskEditTarget?
    @State private var quickAddDate: QuickAddDateWrapper?
    @State private var undoToken: UndoToken?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(home: Home) {
        self.home = home
        _tasks = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Task.dueAt, ascending: true)],
            predicate: BoardView.taskPredicate(for: home),
            animation: .default)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = LanguageManager.activeLocale
        return cal
    }

    private static func monthStart(_ date: Date, _ cal: Calendar = .current) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HMSpacing.m) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    Divider().padding(.vertical, HMSpacing.xs)
                    agendaSection
                }
                .padding(HMSpacing.m)
            }
            .background(HMColor.background)
            .undoToast($undoToken, onUndo: undoComplete)
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $quickAddDate) { sheet in
                QuickAddView(home: home, type: .chore, presetDueDate: sheet.date)
            }
            .sheet(item: $editTarget) { target in
                TaskDetailView(task: target.task, home: home)
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            .accessibilityLabel("calendar.previous")

            Spacer()

            Text(monthTitle)
                .font(HMTypography.title)
                .foregroundStyle(HMColor.primaryText)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .accessibilityLabel("calendar.next")
        }
        .overlay(alignment: .trailing) {
            if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                Button("calendar.today") { goToToday() }
                    .font(HMTypography.caption)
                    .buttonStyle(.borderless)
                    .offset(y: 28)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInGrid(), id: \.self) { day in
                dayCell(day)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let dayTasks = tasksByDay[calendar.startOfDay(for: day)] ?? []

        Button {
            withAnimation(HMMotion.spring) { selectedDate = day }
            HMHaptics.selection()
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(.callout, design: .rounded).weight(isToday ? .bold : .regular))
                    .foregroundStyle(dayNumberColor(inMonth: inMonth, isToday: isToday, isSelected: isSelected))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(isSelected ? HMColor.accent : (isToday ? HMColor.accent.opacity(0.14) : Color.clear))
                    )
                dotRow(dayTasks)
                    .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(inMonth ? 1 : 0.35)
    }

    private func dayNumberColor(inMonth: Bool, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return HMColor.accent }
        return inMonth ? HMColor.primaryText : HMColor.tertiaryText
    }

    @ViewBuilder
    private func dotRow(_ dayTasks: [Task]) -> some View {
        let colors = dotColors(for: dayTasks)
        HStack(spacing: 3) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle().fill(color).frame(width: 5, height: 5)
            }
        }
    }

    /// その日のタスク種別から最大3つの色ドットを作る。
    private func dotColors(for dayTasks: [Task]) -> [Color] {
        guard !dayTasks.isEmpty else { return [] }
        var colors: [Color] = []
        if dayTasks.contains(where: { $0.taskTypeValue == .chore }) { colors.append(HMColor.chore) }
        if dayTasks.contains(where: { $0.taskTypeValue == .request }) { colors.append(HMColor.request) }
        return colors
    }

    // MARK: - Agenda

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()
                                                .locale(LanguageManager.activeLocale)))
                    .font(HMTypography.heading)
                    .foregroundStyle(HMColor.primaryText)
                Spacer()
                Button {
                    quickAddDate = QuickAddDateWrapper(date: selectedDate)
                } label: {
                    Label("calendar.add", systemImage: "plus.circle.fill")
                        .font(HMTypography.callout.weight(.semibold))
                        .foregroundStyle(HMColor.accent)
                }
            }

            let dayTasks = tasksForSelectedDay
            if dayTasks.isEmpty {
                HMEmptyState(systemImage: "calendar",
                             title: "calendar.empty.title",
                             message: "calendar.empty.message")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HMSpacing.l)
            } else {
                ForEach(dayTasks, id: \.objectID) { task in
                    HMCard {
                        TaskRow(task: task,
                                home: home,
                                onComplete: { complete(task) },
                                onOpen: { editTarget = TaskEditTarget(task: task) })
                    }
                }
            }
        }
    }

    private var tasksForSelectedDay: [Task] {
        let start = calendar.startOfDay(for: selectedDate)
        return (tasksByDay[start] ?? []).sorted {
            ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
        }
    }

    // MARK: - Data

    private var tasksByDay: [Date: [Task]] {
        Dictionary(grouping: tasks.compactMap { task -> (Date, Task)? in
            guard let due = task.dueAt else { return nil }
            return (calendar.startOfDay(for: due), task)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide).locale(LanguageManager.activeLocale))
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        guard first < symbols.count else { return symbols }
        return Array(symbols[first...] + symbols[..<first])
    }

    private func daysInGrid() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    // MARK: - Actions

    private func changeMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(HMMotion.smooth) { displayedMonth = CalendarView.monthStart(next) }
    }

    private func goToToday() {
        withAnimation(HMMotion.smooth) {
            displayedMonth = CalendarView.monthStart(Date())
            selectedDate = calendar.startOfDay(for: Date())
        }
    }

    private func complete(_ task: Task) {
        let service = TaskService(context: viewContext)
        guard let result = HMErrorReporter.attemptValue("タスク完了", logger: calendarLogger, {
            try service.complete(task, by: home.currentMember)
        }) else { return }
        appState.analytics.track(task.taskTypeValue == .request ? .requestCompleted : .taskCompleted)
        undoToken = UndoToken(completedID: result.completedTask.objectID,
                              generatedID: result.generatedTask?.objectID)
    }

    private func undoComplete(_ token: UndoToken) {
        let service = TaskService(context: viewContext)
        guard let task = try? viewContext.existingObject(with: token.completedID) as? Task else { return }
        let generated = token.generatedID.flatMap { try? viewContext.existingObject(with: $0) as? Task }
        HMErrorReporter.attempt("完了の取り消し", logger: calendarLogger) {
            try service.reactivate(task, removingGenerated: generated)
        }
    }
}

/// `.sheet(item:)` 用に Date を Identifiable で包む。
private struct QuickAddDateWrapper: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
