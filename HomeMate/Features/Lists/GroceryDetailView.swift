//
//  GroceryDetailView.swift
//  HomeMate
//
//  買い物アイテムの詳細。名前・数量・カテゴリ・メモの編集と写真の添付を行う。
//

import SwiftUI
import CoreData
import UIKit
import os

private let groceryDetailLogger = Logger(subsystem: "com.yostfandy.HomeMate", category: "grocerydetail")

struct GroceryEditTarget: Identifiable {
    let id = UUID()
    let item: GroceryItem
}

struct GroceryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: GroceryItem

    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var notes: String = ""
    @State private var category: GroceryCategory?
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Date()
    @State private var isAllDay: Bool = true
    @State private var recurrence: RecurrenceRule = .none
    @State private var showSchedule = false
    @State private var photoRefresh = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("grocerydetail.name") {
                    TextField("grocerydetail.name", text: $name)
                }

                Section("grocerydetail.quantity") {
                    QuantityField(text: $quantity, placeholderKey: "grocerydetail.quantity.placeholder")
                }

                Section {
                    HMNavRow(title: "schedule.title",
                             systemImage: "calendar",
                             value: scheduleSummary,
                             tint: HMColor.grocery) {
                        showSchedule = true
                    }
                }

                Section("grocerydetail.category") {
                    Picker("grocerydetail.category", selection: $category) {
                        Text("grocerydetail.category.none").tag(GroceryCategory?.none)
                        ForEach(GroceryCategory.allCases, id: \.self) { option in
                            Text(option.titleKey).tag(GroceryCategory?.some(option))
                        }
                    }
                }

                Section("grocerydetail.notes") {
                    TextField("grocerydetail.notes.placeholder", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("taskdetail.photos") {
                    AttachmentsGalleryView(
                        attachments: item.attachmentsArray,
                        onAddImages: { addPhotos($0) },
                        onDelete: { deletePhoto($0) })
                        .id(photoRefresh)
                }
            }
            .navigationTitle("grocerydetail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = item.name ?? ""
                quantity = item.quantity ?? ""
                notes = item.notes ?? ""
                category = item.categoryValue
                if let due = item.dueAt {
                    hasDueDate = true
                    dueDate = due
                } else {
                    hasDueDate = false
                    dueDate = Date()
                }
                isAllDay = item.isAllDay
                recurrence = item.recurrenceRule
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleEditorView(hasDueDate: $hasDueDate,
                                   dueDate: $dueDate,
                                   recurrence: $recurrence,
                                   isAllDay: $isAllDay,
                                   notificationOffsetMinutes: .constant(NotificationLeadTime.off.rawValue),
                                   allowNotification: false,
                                   allowRecurrence: true)
            }
        }
    }

    private var scheduleSummary: String {
        var parts: [String] = []
        if hasDueDate {
            let cal = Calendar.current
            if cal.isDateInToday(dueDate) {
                parts.append(LanguageManager.localized("common.today"))
            } else if cal.isDateInTomorrow(dueDate) {
                parts.append(LanguageManager.localized("common.tomorrow"))
            } else {
                parts.append(dueDate.formatted(Date.FormatStyle(date: .abbreviated)
                    .locale(LanguageManager.activeLocale)))
            }
            if !isAllDay {
                parts.append(dueDate.formatted(Date.FormatStyle(time: .shortened)
                    .locale(LanguageManager.activeLocale)))
            }
        }
        if recurrence.isRepeating {
            parts.append(recurrence.summary(locale: LanguageManager.activeLocale))
        }
        return parts.isEmpty ? LanguageManager.localized("schedule.none") : parts.joined(separator: " · ")
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        item.quantity = trimmedQuantity.isEmpty ? nil : trimmedQuantity
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        item.categoryValue = category
        let service = GroceryService(context: viewContext)
        item.updatedAt = Date()
        HMErrorReporter.attempt("買い物を保存", logger: groceryDetailLogger) {
            try service.updateSchedule(item, dueAt: hasDueDate ? dueDate : nil, isAllDay: isAllDay, recurrence: recurrence)
            try viewContext.save()
        }
        dismiss()
    }

    private func addPhotos(_ images: [UIImage]) {
        let service = AttachmentService(context: viewContext)
        for image in images {
            HMErrorReporter.attempt("写真を追加", logger: groceryDetailLogger) {
                try service.addImage(image, to: item)
            }
        }
        photoRefresh += 1
    }

    private func deletePhoto(_ attachment: Attachment) {
        let service = AttachmentService(context: viewContext)
        HMErrorReporter.attempt("写真を削除", logger: groceryDetailLogger) {
            try service.delete(attachment)
        }
        photoRefresh += 1
    }
}
