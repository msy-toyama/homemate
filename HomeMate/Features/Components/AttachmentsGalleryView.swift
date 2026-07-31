//
//  AttachmentsGalleryView.swift
//  HomeMate
//
//  タスク・買い物で共用する写真ギャラリー。
//  横スクロールのサムネイル、追加（PhotosPicker・複数選択）、全画面表示、削除。
//

import SwiftUI
import PhotosUI

struct AttachmentsGalleryView: View {
    let attachments: [Attachment]
    var maxCount: Int = AttachmentService.maxPhotosPerItem
    var onAddImages: ([UIImage]) -> Void
    var onDelete: (Attachment) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewerImage: ViewerImage?
    @State private var isLoading = false

    private var remaining: Int { max(0, maxCount - attachments.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: HMSpacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HMSpacing.s) {
                    ForEach(attachments, id: \.objectID) { attachment in
                        thumbnail(attachment)
                    }
                    if remaining > 0 {
                        addTile
                    }
                }
                .padding(.vertical, 2)
            }
            if isLoading {
                HStack(spacing: HMSpacing.s) {
                    ProgressView()
                    Text("attachments.adding")
                        .font(HMTypography.caption)
                        .foregroundStyle(HMColor.secondaryText)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            load(items)
        }
        .fullScreenCover(item: $viewerImage) { item in
            AttachmentViewer(image: item.image)
        }
    }

    @ViewBuilder
    private func thumbnail(_ attachment: Attachment) -> some View {
        if let image = attachment.uiImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        HMHaptics.impact(.light)
                        onDelete(attachment)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                            .padding(3)
                    }
                    .accessibilityLabel("attachments.delete")
                }
                .onTapGesture {
                    viewerImage = ViewerImage(image: image)
                }
                .accessibilityLabel("attachments.photo")
        }
    }

    private var addTile: some View {
        PhotosPicker(selection: $pickerItems,
                     maxSelectionCount: remaining,
                     matching: .images) {
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 22))
                Text("attachments.add")
                    .font(HMTypography.caption)
            }
            .foregroundStyle(HMColor.accent)
            .frame(width: 76, height: 76)
            .background(HMColor.tint(HMColor.accent, 0.10))
            .clipShape(RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HMRadius.chip, style: .continuous)
                    .strokeBorder(HMColor.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .accessibilityLabel("attachments.add")
    }

    private func load(_ items: [PhotosPickerItem]) {
        isLoading = true
        _Concurrency.Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                if !images.isEmpty { onAddImages(images) }
                pickerItems = []
                isLoading = false
            }
        }
    }
}

/// 全画面表示用に UIImage を Identifiable で包む。
private struct ViewerImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 添付写真の全画面ビューア。
private struct AttachmentViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, Color.black.opacity(0.4))
                    .padding()
            }
            .accessibilityLabel("common.done")
        }
    }
}
