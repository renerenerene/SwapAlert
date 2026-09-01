import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: IconGenerator OUTPUT.png\n", stderr)
    exit(2)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Could not create graphics context\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let backgroundPath = CGPath(
    roundedRect: CGRect(x: 52, y: 52, width: 920, height: 920),
    cornerWidth: 214,
    cornerHeight: 214,
    transform: nil
)
context.saveGState()
context.addPath(backgroundPath)
context.clip()
let colors = [
    NSColor(calibratedRed: 0.31, green: 0.55, blue: 1.0, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.39, green: 0.36, blue: 1.0, alpha: 1).cgColor
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 130, y: 900),
    end: CGPoint(x: 900, y: 130),
    options: []
)
context.restoreGState()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -24), blur: 32, color: NSColor(calibratedWhite: 0.08, alpha: 0.34).cgColor)
context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(56)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(
    CGPath(
        roundedRect: CGRect(x: 278, y: 278, width: 468, height: 468),
        cornerWidth: 96,
        cornerHeight: 96,
        transform: nil
    )
)
context.strokePath()
context.restoreGState()

context.setFillColor(NSColor.white.cgColor)
context.addPath(
    CGPath(
        roundedRect: CGRect(x: 395, y: 395, width: 234, height: 234),
        cornerWidth: 38,
        cornerHeight: 38,
        transform: nil
    )
)
context.fillPath()

context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(46)
context.setLineCap(.round)

for x in [356.0, 468.0, 580.0, 692.0] {
    context.move(to: CGPoint(x: x, y: 212))
    context.addLine(to: CGPoint(x: x, y: 278))
    context.move(to: CGPoint(x: x, y: 746))
    context.addLine(to: CGPoint(x: x, y: 812))
}

for y in [356.0, 468.0, 580.0, 692.0] {
    context.move(to: CGPoint(x: 212, y: y))
    context.addLine(to: CGPoint(x: 278, y: y))
    context.move(to: CGPoint(x: 746, y: y))
    context.addLine(to: CGPoint(x: 812, y: y))
}
context.strokePath()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Could not encode icon\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
} catch {
    fputs("Could not write icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
