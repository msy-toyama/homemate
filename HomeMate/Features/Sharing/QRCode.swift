//
//  QRCode.swift
//  HomeMate
//
//  文字列（共有 URL）から QR コード画像を生成するユーティリティ。
//  招待画面で「見せて読み取ってもらう」共有に使う。iCloud の生 URL を
//  ユーザーの目に触れさせずに、対面・別端末での参加を可能にする。
//

import CoreImage.CIFilterBuiltins
import UIKit

enum QRCode {
    private static let context = CIContext()

    /// 指定文字列を QR コード化した画像。生成に失敗した場合は nil。
    /// - Parameters:
    ///   - string: エンコードする文字列（共有 URL 等）。
    ///   - scale: 出力の拡大率（既定 12 = くっきり印刷/表示向け）。
    static func image(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // 誤り訂正レベル M（15%）: 表示・スクショ共有時の可読性と密度のバランス。
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
