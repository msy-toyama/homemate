//
//  TaskDetailView.swift
//  HomeMate
//
//  タスク（家事・お願い）の編集画面。タイトル・担当・負担・スケジュール・
//  公開範囲・メモを編集でき、複製と削除（繰り返しは系列まとめて削除も選べる）に対応。
//

import SwiftUI
import CoreData
import UIKit
import os

private let taskDetailLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "taskdetail")

/// `.sheet(item:)` で Task を渡すための Identifiable ラッパー。
struct TaskEditTarget: Identifiable {
    let task: Task
    var id: NSManagedObjectID { task.objectID }
}

struct TaskDetailView: View {
    let task: Task
    let home: Home

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var title: String
    @State private var assigneeId: UUID?
    @State private var effort: EffortLevel
    @State private var rotation: RotationPolicy
    @State private var notes: String
    @State private var visibility: TaskVisibility
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isAllDay: Bool
    @State private var recurrence: RecurrenceRule
    @State private var notificationOffsetMinutes: Int16

    @State private var showSchedule = false
    @State private var showDeleteDialog = false
    @State private var photoRefresh = 0

    init(task: Task, home: Home) {
        self.task = task
        self.home = home
        _title = State(initialValue: task.resolvedTitle)
        _assigneeId = State(initialValue: task.assignedToMemberId)
        _effort = State(initialValue: task.effortLevelValue)
        _rotation = State(initialValue: task.rotationPolicyValue)
        _notes = State(initialValue: task.notes ?? "")
        _visibility = State(initialValue: task.visibilityValue)
        _hasDueDate = State(initialValue: task.dueAt != nil)
        _dueDate = State(initialValue: task.dueAt ?? (Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()))
        _isAllDay = State(initialValue: task.isAllDay)
        _recurrence = State(initialValue: task.recurrenceRule)
        _notificationOffsetMinutes = State(initialValue: task.notificationOffsetMinutes)
    }

    private var members: [Member] { home.membersArray }
    private var isRequest: Bool { task.taskTypeValue == .request }
    private var typeTint: Color { isRequest ? HMColor.request : HMColor.chore }

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if isRequest, assigneeId == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                assigneeSection
                scheduleSection
                if !isRequest {
                    effortSection
                    visibilitySection
                }
                notesSection
                photosSection
                actionsSection
            }
            .navigationTitle("taskdetail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("taskdetail.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleEditorView(hasDueDate: $hasDueDate,
                                   dueDate: $dueDate,
                                   recurrence: $recurrence,
                                   isAllDay: $isAllDay,
                                   notificationOffsetMinutes: $notificationOffsetMinutes,
                                   allowRecurrence: !isRequest)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var titleSection: some View {
        Section {
            TextField("taskdetail.title.placeholder", text: $title, axis: .vertical)
                .font(HMTypography.body)
        }
    }

    @ViewBuilder private var assigneeSection: some View {
        Section(isRequest ? "taskdetail.requestTo" : "taskdetail.assignee") {
            Picker(isRequest ? "taskdetail.requestTo" : "taskdetail.assignee",
                   selection: $assigneeId) {
                if !isRequest {
                    Text("quickadd.assignee.anyone").tag(UUID?.none)
                }
                ForEach(members, id: \.objectID) { member in
                    Text(member.resolvedDisplayName).tag(UUID?.some(member.id ?? UUID()))
                }
            }
            if !isRequest, recurrence.isRepeating, members.count > 1 {
                Picker("taskdetail.rotation", selection: $rotation) {
                    ForEach(RotationPolicy.allCases) { policy in
                        Text(policy.titleKey).tag(policy)
                    }
                }
            }
        }
    }

    @ViewBuilder private var scheduleSection: some View {
        Section {
            HMNavRow(title: "schedule.title",
                     systemImage: "calendar",
                     value: scheduleSummary,
                     tint: typeTint) {
                showSchedule = true
            }
        }
    }

    @ViewBuilder private var effortSection: some View {
        Section("taskdetail.effort") {
            Picker("taskdetail.effort", selection: $effort) {
                ForEach(EffortLevel.allCases) { level in
                    Text(level.titleKey).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var visibilitySection: some View {
        Section {
            Picker("taskdetail.visibility", selection: $visibility) {
                ForEach(TaskVisibility.allCases) { v in
                    Label(v.titleKey, systemImage: v.symbolName).tag(v)
                }
            }
        } footer: {
            if visibility == .private {
                Text("taskdetail.visibility.private.note")
            }
        }
    }

    @ViewBuilder private var notesSection: some View {
        Section("taskdetail.notes") {
            TextField("taskdetail.notes.placeholder", text: $notes, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    @ViewBuilder private var photosSection: some View {
        Section("taskdetail.photos") {
            AttachmentsGalleryView(
                attachments: task.attachmentsArray,
                onAddImages: { addPhotos($0) },
                onDelete: { deletePhoto($0) })
                .id(photoRefresh)
        }
    }

    private func addPhotos(_ images: [UIImage]) {
        let service = AttachmentService(context: viewContext)
        for image in images {
            HMErrorReporter.attempt("写真を追加", logger: taskDetailLogger) {
                try service.addImage(image, to: task)
            }
        }
        photoRefresh += 1
    }

    private func deletePhoto(_ attachment: Attachment) {
        let service = AttachmentService(context: viewContext)
        HMErrorReporter.attempt("写真を削除", logger: taskDetailLogger) {
            try service.delete(attachment)
        }
        photoRefresh += 1
    }

    @ViewBuilder private var actionsSection: some View {
        Section {
            Button {
                duplicate()
            } label: {
                Label("taskdetail.duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                if recurrence.isRepeating, task.seriesId != nil {
                    showDeleteDialog = true
                } else {
                    delete(series: false)
                }
            } label: {
                Label("taskdetail.delete", systemImage: "trash")
            }
            .confirmationDialog("taskdetail.delete.confirm.title",
                                isPresented: $showDeleteDialog,
                                titleVisibility: .visible) {
                Button("taskdetail.delete.thisOnly", role: .destructive) {
                    delete(series: false)
                }
                Button("taskdetail.delete.series", role: .destructive) {
                    delete(series: true)
                }
                Button("common.cancel", role: .cancel) {}
            }
        }
    }

    private var scheduleSummary: String {
        var parts: [String] = []
        if hasDueDate {
            if isAllDay {
                parts.append(dueDate.formatted(Date.FormatStyle(date: .abbreviated)
                                                .locale(LanguageManager.activeLocale))
                             + " · " + LanguageManager.localized("schedule.allDay"))
            } else {
                parts.append(dueDate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
                                                .locale(LanguageManager.activeLocale)))
            }
        }
        if !isRequest, recurrence.isRepeating {
            parts.append(recurrence.summary(locale: LanguageManager.activeLocale))
        }
        if parts.isEmpty {
            return LanguageManager.localized("schedule.none")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func save() {
        let service = TaskService(context: viewContext)
        let assignee = home.member(withID: assigneeId)
        let rule = isRequest ? RecurrenceRule.none : recurrence
        HMErrorReporter.attempt("タスクを保存", logger: taskDetailLogger) {
            try service.update(task,
                            title: title,
                            assignedTo: assignee,
                            dueAt: hasDueDate ? dueDate : nil,
                            isAllDay: isAllDay,
                            recurrence: rule,
                            rotation: rotation,
                            effort: effort,
                            visibility: isRequest ? .shared : visibility,
                            notificationOffsetMinutes: hasDueDate ? notificationOffsetMinutes : NotificationLeadTime.off.rawValue,
                            notes: notes.isEmpty ? nil : notes)
        }
        HMHaptics.success()
        dismiss()
    }

    private func duplicate() {
        let service = TaskService(context: viewContext)
        let assignee = home.member(withID: assigneeId)
        HMErrorReporter.attempt("タスクを複製", logger: taskDetailLogger) {
            try service.create(in: home,
                                title: title,
                                type: task.taskTypeValue,
                                assignedTo: assignee,
                                dueAt: hasDueDate ? dueDate : nil,
                                isAllDay: isAllDay,
                                recurrence: isRequest ? .none : recurrence,
                                rotation: rotation,
                                effort: effort,
                                visibility: isRequest ? .shared : visibility,
                                notificationOffsetMinutes: hasDueDate ? notificationOffsetMinutes : NotificationLeadTime.off.rawValue,
                                notes: notes.isEmpty ? nil : notes,
                                by: home.currentMember)
        }
        appState.analytics.track(.taskCreated)
        if !isRequest, recurrence.isRepeating {
            appState.analytics.track(.recurringTaskCreated)
        }
        HMHaptics.impact(.light)
        dismiss()
    }

    private func delete(series: Bool) {
        let service = TaskService(context: viewContext)
        HMErrorReporter.attempt("タスクを削除", logger: taskDetailLogger) {
            if series {
                try service.deleteSeries(task)
            } else {
                try service.archive(task)
            }
        }
        HMHaptics.impact(.medium)
        dismiss()
    }
}
