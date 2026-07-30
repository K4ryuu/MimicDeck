// Renders the DMG window background. Run through `swift`, writes a PNG to
// the path given as the first argument.

import AppKit
import CoreGraphics
import Foundation

let width = 640
let height = 400
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg-background.png"

guard let context = CGContext(
    data: nil,
    width: width * 2,
    height: height * 2,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("could not create bitmap context\n".utf8))
    exit(1)
}

context.scaleBy(x: 2, y: 2)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1),
        CGColor(red: 0.14, green: 0.15, blue: 0.21, alpha: 1)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(height)),
    end: CGPoint(x: CGFloat(width), y: 0),
    options: []
)

// Soft accent glow behind the app icon slot.
let glow = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.35, green: 0.45, blue: 0.95, alpha: 0.22),
        CGColor(red: 0.35, green: 0.45, blue: 0.95, alpha: 0)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: 165, y: 215), startRadius: 0,
    endCenter: CGPoint(x: 165, y: 215), endRadius: 170,
    options: []
)

// The arrow between the two icons.
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.30))
context.setLineWidth(2.5)
context.setLineCap(.round)
context.move(to: CGPoint(x: 268, y: 215))
context.addLine(to: CGPoint(x: 372, y: 215))
context.strokePath()
context.move(to: CGPoint(x: 358, y: 227))
context.addLine(to: CGPoint(x: 372, y: 215))
context.addLine(to: CGPoint(x: 358, y: 203))
context.strokePath()

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("could not render image\n".utf8))
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
bitmap.size = NSSize(width: width, height: height)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode png\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
