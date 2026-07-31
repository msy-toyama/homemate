//
//  CloudSharingController.swift
//  HomeMate
//
//  UICloudSharingController を SwiftUI から表示するためのラッパー。
//  招待リンクの作成・送信・参加者管理の標準 UI を提供する。
//

import SwiftUI
import CloudKit
import UIKit

struct CloudSharingController: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let title: String
    var onSaveShare: (() -> Void)?
    var onStopSharing: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title,
                    thumbnailData: Self.brandedThumbnailData(),
                    onSaveShare: onSaveShare,
                    onStopSharing: onStopSharing)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    /// 招待カードに表示する、アプリらしいブランドサムネイル（コーラル地に家アイコン）。
    /// アプリアイコンはアセットカタログ管理で直接読めないため、デザインカラーで描画する。
    private static func brandedThumbnailData() -> Data? {
        let size = CGSize(width: 180, height: 180)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let background = UIColor(named: "AccentColor")
                ?? UIColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1)
            background.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 40).fill()

            let config = UIImage.SymbolConfiguration(pointSize: 92, weight: .semibold)
            if let symbol = UIImage(systemName: "house.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2,
                                     y: (size.height - symbol.size.height) / 2)
                symbol.draw(at: origin)
            }
        }
        return image.pngData()
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String
        let thumbnailData: Data?
        let onSaveShare: (() -> Void)?
        let onStopSharing: (() -> Void)?

        init(title: String,
             thumbnailData: Data?,
             onSaveShare: (() -> Void)?,
             onStopSharing: (() -> Void)?) {
            self.title = title
            self.thumbnailData = thumbnailData
            self.onSaveShare = onSaveShare
            self.onStopSharing = onStopSharing
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { title }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? { thumbnailData }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            // 失敗してもユーザーを責めない。標準 UI がエラーを表示する。
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            // 招待が実際に保存・送信されたタイミングで共有状態を確定する。
            onSaveShare?()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStopSharing?()
        }
    }
}
