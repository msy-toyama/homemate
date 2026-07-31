#!/usr/bin/env swift
//
//  generate_app_icon.swift
//  HomeMate アプリアイコンを CoreGraphics/AppKit で生成する開発用スクリプト。
//  使い方: swift generate_app_icon.swift <出力ディレクトリ>
//  light / dark / tinted の 1024x1024 PNG を書き出す。
//

import AppKit

let size: CGFloat = 1024

enum Mode {
    case light, dark, tinted
}

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func roundedHousePath(bodyRect: NSRect, roofApex: NSPoint, roofLeft: NSPoint, roofRight: NSPoint, radius: CGFloat) -> NSBezierPath {
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
    let roof = NSBezierPath()
    roof.move(to: roofLeft)
    roof.line(to: NSPoint(x: roofApex.x, y: roofApex.y))
    roof.line(to: roofRight)
    roof.line(to: NSPoint(x: roofRight.x, y: roofRight.y - 18))
    roof.line(to: NSPoint(x: roofLeft.x, y: roofLeft.y - 18))
    roof.close()
    roof.lineJoinStyle = .round
    body.append(roof)
    return body
}

/// 家の中に置くチェックマーク（太いストロークを塗りに変換した形）。
/// 家事ボードの「完了」を表す、シンプルで視認性の高いシンボル。
func checkmarkPath(start: NSPoint, mid: NSPoint, end: NSPoint, lineWidth: CGFloat) -> NSBezierPath {
    let stroke = NSBezierPath()
    stroke.move(to: start)
    stroke.line(to: mid)
    stroke.line(to: end)
    stroke.lineWidth = lineWidth
    stroke.lineCapStyle = .round
    stroke.lineJoinStyle = .round
    // ストロークを塗り可能なアウトラインに変換しておくと、グラデーションで塗れる。
    let cg = stroke.cgPath.copy(strokingWithWidth: lineWidth,
                                lineCap: .round, lineJoin: .round, miterLimit: 10)
    return NSBezierPath(cgPath: cg)
}

func makeImage(mode: Mode) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let full = NSRect(x: 0, y: 0, width: size, height: size)

    // 背景グラデーション
    let bgColors: [NSColor]
    switch mode {
    case .light:
        bgColors = [srgb(0.96, 0.55, 0.42), srgb(0.90, 0.39, 0.34)]
    case .dark:
        bgColors = [srgb(0.42, 0.16, 0.14), srgb(0.26, 0.10, 0.10)]
    case .tinted:
        bgColors = [srgb(0.10, 0.10, 0.10), srgb(0.0, 0.0, 0.0)]
    }
    let gradient = NSGradient(starting: bgColors[0], ending: bgColors[1])!
    gradient.draw(in: full, angle: -45)

    // やわらかい装飾の円（右上にうっすら）
    if mode != .tinted {
        srgb(1, 1, 1, 0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.55, y: size * 0.6, width: size * 0.6, height: size * 0.6)).fill()
    }

    // 家の形（大きめ・中央寄せ）
    let bodyRect = NSRect(x: 287, y: 220, width: 450, height: 355)
    let house = roundedHousePath(bodyRect: bodyRect,
                                 roofApex: NSPoint(x: 512, y: 818),
                                 roofLeft: NSPoint(x: 205, y: 573),
                                 roofRight: NSPoint(x: 819, y: 573),
                                 radius: 40)

    let houseColor: NSColor
    switch mode {
    case .light, .dark: houseColor = srgb(1, 1, 1, 0.97)
    case .tinted: houseColor = srgb(0.92, 0.92, 0.92, 1)
    }

    // 家の影
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40,
                  color: srgb(0, 0, 0, 0.22).cgColor)
    houseColor.setFill()
    house.fill()
    ctx.restoreGState()

    // 家の中のチェックマーク（完了の象徴・家の拡大に合わせて拡大）
    let check = checkmarkPath(start: NSPoint(x: 416, y: 386),
                              mid: NSPoint(x: 483, y: 318),
                              end: NSPoint(x: 618, y: 462),
                              lineWidth: 66)
    switch mode {
    case .light:
        let cg = NSGradient(starting: srgb(0.95, 0.45, 0.38), ending: srgb(0.88, 0.34, 0.40))!
        cg.draw(in: check, angle: -90)
    case .dark:
        let cg = NSGradient(starting: srgb(0.97, 0.51, 0.44), ending: srgb(0.90, 0.38, 0.42))!
        cg.draw(in: check, angle: -90)
    case .tinted:
        srgb(0.55, 0.55, 0.55, 1).setFill()
        check.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("PNG encode failed for \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    } catch {
        FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
write(makeImage(mode: .light), to: "\(outDir)/AppIcon-1024.png")
write(makeImage(mode: .dark), to: "\(outDir)/AppIcon-1024-dark.png")
write(makeImage(mode: .tinted), to: "\(outDir)/AppIcon-1024-tinted.png")
