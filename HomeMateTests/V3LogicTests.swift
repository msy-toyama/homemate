//
//  V3LogicTests.swift
//  HomeMateTests
//
//  HomeMate V3（複数ボード・写真添付・言語解決）のコアロジック単体テスト。
//

import Testing
import CoreData
import UIKit
@testable import HomeMate

struct V3LogicTests {

    @MainActor
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    private func makeImage(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - AttachmentService の縮小

    @Test func downscaleShrinksLongSideToMax() {
        let image = makeImage(CGSize(width: 3200, height: 2400))
        let result = AttachmentService.downscaled(image)
        #expect(max(result.size.width, result.size.height) == AttachmentService.maxDimension)
        // 縦横比を維持（3200:2400 = 4:3 → 1600:1200）。
        #expect(result.size.width == 1600)
        #expect(result.size.height == 1200)
    }

    @Test func downscaleKeepsSmallImage() {
        let image = makeImage(CGSize(width: 800, height: 600))
        let result = AttachmentService.downscaled(image)
        #expect(result.size.width == 800)
        #expect(result.size.height == 600)
    }

    @Test func prepareReturnsJPEGData() {
        let image = makeImage(CGSize(width: 1000, height: 1000))
        let prepared = AttachmentService.prepare(image)
        #expect(prepared != nil)
        #expect((prepared?.data.count ?? 0) > 0)
        #expect(prepared?.size == CGSize(width: 1000, height: 1000))
    }

    @Test @MainActor func addImageStoresAndDeleteRemoves() throws {
        let ctx = makeContext()
        let home = try HomeService(context: ctx)
            .createHome(name: "Test", homeType: .roommates, currentMemberName: "Me", locale: "ja")
        let task = Task(context: ctx)
        task.id = UUID(); task.title = "T"; task.status = "active"
        task.taskTypeValue = .chore; task.home = home
        try ctx.save()

        let service = AttachmentService(context: ctx)
        let attachment = try service.addImage(makeImage(CGSize(width: 400, height: 400)), to: task)
        #expect(attachment != nil)
        #expect(task.attachmentsArray.count == 1)
        #expect(task.attachmentsArray.first?.uiImage != nil)

        if let attachment {
            try service.delete(attachment)
            #expect(task.attachmentsArray.isEmpty)
        }
    }

    // MARK: - ボードの可視性フィルタ

    @Test @MainActor func boardPredicateFiltersPrivateOfOthers() throws {
        let ctx = makeContext()
        let home = try HomeService(context: ctx)
            .createHome(name: "Board", homeType: .roommates, currentMemberName: "Me", locale: "ja")
        let meId = home.currentMember?.id

        let other = Member(context: ctx)
        other.id = UUID(); other.displayName = "Other"; other.isCurrentUser = false
        other.joinedAt = Date(); other.home = home

        func makeTask(_ title: String, visibility: TaskVisibility, creator: UUID?) {
            let task = Task(context: ctx)
            task.id = UUID(); task.title = title; task.status = "active"
            task.taskTypeValue = .chore; task.home = home
            task.visibilityValue = visibility
            task.createdByMemberId = creator
        }
        makeTask("shared", visibility: .shared, creator: other.id)
        makeTask("myPrivate", visibility: .private, creator: meId)
        makeTask("otherPrivate", visibility: .private, creator: other.id)
        try ctx.save()

        let request = Task.fetchRequest()
        request.predicate = BoardView.taskPredicate(for: home)
        let visible = try ctx.fetch(request)
        let titles = Set(visible.compactMap { $0.title })
        #expect(titles.contains("shared"))
        #expect(titles.contains("myPrivate"))
        #expect(!titles.contains("otherPrivate"))
    }

    // MARK: - ボード一覧とアーカイブ

    @Test @MainActor func listHomesExcludesArchived() throws {
        let ctx = makeContext()
        let service = HomeService(context: ctx)
        let a = try service.createBoard(name: "A", homeType: .solo, currentMemberName: "Me", locale: "ja")
        _ = try service.createBoard(name: "B", homeType: .family, currentMemberName: "Me", locale: "ja")
        #expect(service.listHomes().count == 2)

        try service.archive(a)
        let remaining = service.listHomes()
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "B")
    }

    // MARK: - 言語解決

    @Test @MainActor func languageManagerResolvesExplicitCodes() {
        let manager = LanguageManager()
        manager.language = .ja
        #expect(manager.resolvedCode == "ja")
        #expect(manager.locale.identifier == "ja")
        manager.language = .en
        #expect(manager.resolvedCode == "en")
        #expect(manager.locale.identifier == "en")
    }
}
