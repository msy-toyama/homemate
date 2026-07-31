//
//  AttachmentService.swift
//  HomeMate
//
//  タスク・買い物への写真添付を管理する。
//  取り込み時に長辺を縮小し、JPEG として保存する（CloudKit/CKAsset 容量に配慮）。
//

import CoreData
import UIKit

struct AttachmentService {
    let context: NSManagedObjectContext

    /// 縮小後の長辺の最大ピクセル数。
    static let maxDimension: CGFloat = 1600
    /// JPEG 圧縮品質。
    static let jpegQuality: CGFloat = 0.8
    /// 1 件あたりの上限枚数。
    static let maxPhotosPerItem = 8

    // MARK: - Add

    @discardableResult
    func addImage(_ image: UIImage, to task: Task) throws -> Attachment? {
        guard let prepared = Self.prepare(image) else { return nil }
        let attachment = makeAttachment(prepared, sortOrder: Int16(task.attachmentsArray.count))
        attachment.task = task
        task.updatedAt = Date()
        try context.save()
        return attachment
    }

    @discardableResult
    func addImage(_ image: UIImage, to grocery: GroceryItem) throws -> Attachment? {
        guard let prepared = Self.prepare(image) else { return nil }
        let attachment = makeAttachment(prepared, sortOrder: Int16(grocery.attachmentsArray.count))
        attachment.grocery = grocery
        grocery.updatedAt = Date()
        try context.save()
        return attachment
    }

    // MARK: - Delete

    func delete(_ attachment: Attachment) throws {
        context.delete(attachment)
        try context.save()
    }

    // MARK: - Helpers

    private func makeAttachment(_ prepared: (data: Data, size: CGSize), sortOrder: Int16) -> Attachment {
        let attachment = Attachment(context: context)
        attachment.id = UUID()
        attachment.imageData = prepared.data
        attachment.width = Int32(prepared.size.width)
        attachment.height = Int32(prepared.size.height)
        attachment.sortOrder = sortOrder
        attachment.createdAt = Date()
        return attachment
    }

    /// 画像を縮小し JPEG データと実サイズを返す。
    static func prepare(_ image: UIImage) -> (data: Data, size: CGSize)? {
        let scaled = downscaled(image)
        guard let data = scaled.jpegData(compressionQuality: jpegQuality) else { return nil }
        return (data, scaled.size)
    }

    /// 長辺が maxDimension を超える場合のみ縮小する。
    static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension Attachment {
    /// 保存された画像データから UIImage を復元する。
    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
}
