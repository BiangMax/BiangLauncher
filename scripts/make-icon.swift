import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(size: Int, filename: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let base = NSBezierPath(roundedRect: NSRect(x: 58, y: 58, width: 908, height: 908), xRadius: 212, yRadius: 212)
    NSGradient(starting: NSColor(red: 0.14, green: 0.20, blue: 0.28, alpha: 1), ending: NSColor(red: 0.035, green: 0.055, blue: 0.09, alpha: 1))!.draw(in: base, angle: -70)
    NSColor(white: 1, alpha: 0.15).setStroke()
    base.lineWidth = 3
    base.stroke()
    for (x, y, bright) in [(245.0, 245.0, false), (245.0, 545.0, false), (545.0, 245.0, false), (545.0, 545.0, true)] {
        let tile = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 234, height: 234), xRadius: 60, yRadius: 60)
        let start = bright ? NSColor(red: 0.65, green: 0.94, blue: 1, alpha: 1) : NSColor(red: 0.32, green: 0.55, blue: 0.69, alpha: 1)
        let end = bright ? NSColor(red: 0.25, green: 0.68, blue: 0.92, alpha: 1) : NSColor(red: 0.16, green: 0.31, blue: 0.44, alpha: 1)
        NSGradient(starting: start, ending: end)!.draw(in: tile, angle: -60)
        NSColor(white: 1, alpha: bright ? 0.4 : 0.13).setStroke()
        tile.lineWidth = 2
        tile.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
}

for size in [16, 32, 128, 256, 512] {
    try render(size: size, filename: "icon_\(size)x\(size).png")
    try render(size: size * 2, filename: "icon_\(size)x\(size)@2x.png")
}
