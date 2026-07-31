//
//  ScheduleEditorView.swift
//  HomeMate
//
//  期限（カレンダー＋時刻）と繰り返しルールを1つのシートで直感的に設定する。
//  スポット / 毎日・N日ごと / 毎週(複数曜日)・N週ごと / 毎月X日・Nヶ月ごと に対応。
//

import SwiftUI

struct ScheduleEditorView: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var recurrence: RecurrenceRule
    /// 終日（時刻指定なし）かどうか。
    @Binding var isAllDay: Bool
    /// 通知タイミング（期限の何分前か）。`-1` は通知しない。
    @Binding var notificationOffsetMinutes: Int16
    /// 通知セクションを表示するか。買い物など通知不要な対象では false。
    var allowNotification: Bool = true
    /// お願いなど繰り返し不要な対象では false にして繰り返しセクションを隠す。
    var allowRecurrence: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                dueSection
                if hasDueDate, allowNotification {
                    notificationSection
                }
                if allowRecurrence {
                    recurrenceSection
                }
            }
            .navigationTitle("schedule.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 期限

    @ViewBuilder private var dueSection: some View {
        Section {
            Toggle(isOn: $hasDueDate.animation(HMMotion.smooth)) {
                Label("schedule.setDue", systemImage: "calendar")
            }
            .tint(HMColor.accent)

            if hasDueDate {
                DatePicker("schedule.date", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(HMColor.accent)
                Toggle(isOn: $isAllDay.animation(HMMotion.smooth)) {
                    Label("schedule.allDay", systemImage: "sun.max")
                }
                .tint(HMColor.accent)
                if !isAllDay {
                    DatePicker("schedule.time", selection: $dueDate, displayedComponents: .hourAndMinute)
                }
            }
        } footer: {
            if !hasDueDate {
                Text("schedule.noDue.note")
            }
        }
    }

    // MARK: - 通知

    @ViewBuilder private var notificationSection: some View {
        Section {
            Picker(selection: leadTimeBinding) {
                ForEach(NotificationLeadTime.allCases) { lead in
                    Text(lead.titleKey).tag(lead)
                }
            } label: {
                Label("schedule.notify.title", systemImage: "bell.badge")
            }
            .tint(HMColor.accent)
        } footer: {
            if isAllDay, notificationOffsetMinutes != NotificationLeadTime.off.rawValue {
                Text("schedule.notify.allDayNote")
            }
        }
    }

    // MARK: - 繰り返し

    @ViewBuilder private var recurrenceSection: some View {
        Section {
            Picker("schedule.repeat", selection: frequencyBinding) {
                Text("repeat.none").tag(RepeatFrequency.none)
                Text("repeat.daily").tag(RepeatFrequency.daily)
                Text("repeat.weekly").tag(RepeatFrequency.weekly)
                Text("repeat.monthly").tag(RepeatFrequency.monthly)
            }
            .pickerStyle(.segmented)
            .disabled(!hasDueDate)

            if hasDueDate, recurrence.frequency != .none {
                Stepper(value: intervalBinding, in: 1...30) {
                    HStack {
                        Text("schedule.interval")
                        Spacer()
                        Text("\(recurrence.interval)")
                            .foregroundStyle(HMColor.secondaryText)
                            .contentTransition(.numericText())
                    }
                }
                .animation(HMMotion.quick, value: recurrence.interval)
            }

            if hasDueDate, recurrence.frequency == .weekly {
                VStack(alignment: .leading, spacing: HMSpacing.s) {
                    Text("schedule.weekdays")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                    HMWeekdayPicker(selection: weekdaysBinding)
                }
                .padding(.vertical, HMSpacing.xs)
            }

            if hasDueDate, recurrence.frequency == .monthly {
                Picker("schedule.dayOfMonth", selection: dayOfMonthBinding) {
                    Text("schedule.dayOfMonth.auto").tag(0)
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
            }
        } header: {
            Text("schedule.repeat")
        } footer: {
            if hasDueDate, recurrence.isRepeating {
                Label(recurrence.summary(locale: LanguageManager.activeLocale), systemImage: "repeat")
                    .font(HMTypography.caption)
                    .foregroundStyle(HMColor.accent)
            } else if hasDueDate {
                Text("schedule.spot.note")
            }
        }
    }

    // MARK: - Bindings（RecurrenceRule のサブ要素）

    private var leadTimeBinding: Binding<NotificationLeadTime> {
        Binding(
            get: { NotificationLeadTime.from(minutes: notificationOffsetMinutes) },
            set: { newValue in
                notificationOffsetMinutes = newValue.rawValue
                HMHaptics.selection()
            }
        )
    }

    private var frequencyBinding: Binding<RepeatFrequency> {
        Binding(
            get: { recurrence.frequency },
            set: { newValue in
                var rule = recurrence
                rule.frequency = newValue
                // 毎週へ切り替えた際、未選択なら基準日の曜日を初期選択にする。
                if newValue == .weekly, rule.weekdays.isEmpty {
                    rule.weekdays = [Calendar.current.component(.weekday, from: dueDate)]
                }
                recurrence = rule
                HMHaptics.selection()
            }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { recurrence.interval },
            set: { recurrence.interval = max(1, $0) }
        )
    }

    private var weekdaysBinding: Binding<Set<Int>> {
        Binding(
            get: { recurrence.weekdays },
            set: { recurrence.weekdays = $0 }
        )
    }

    private var dayOfMonthBinding: Binding<Int> {
        Binding(
            get: { recurrence.dayOfMonth },
            set: { recurrence.dayOfMonth = $0 }
        )
    }
}
