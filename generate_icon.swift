#!/usr/bin/env swift
// Generates YATDL app icon: dark indigo gradient + amber bolt.circle.fill
import AppKit

_ = NSApplication.shared  // required for AppKit drawing in CLI context

let side = 1024

// Create a CGBitmapContext for off-screen rendering — avoids NSImage.lockFocus
// which requires a display-connected graphics context
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: side, height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fputs("CGContext init failed\n", stderr); exit(1) }

// Route AppKit drawing calls through this context
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

// -- Background: clip to macOS rounded-rect, fill with gradient -------------

let bgRect = NSRect(x: 0, y: 0, width: side, height: side)
NSBezierPath(roundedRect: bgRect, xRadius: 230, yRadius: 230).setClip()

let colors = [CGColor(red: 0.09, green: 0.10, blue: 0.26, alpha: 1.0),
              CGColor(red: 0.03, green: 0.04, blue: 0.14, alpha: 1.0)] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(gradient,
    start: CGPoint(x: 0, y: CGFloat(side)),
    end:   CGPoint(x: CGFloat(side), y: 0),
    options: [])

// Subtle amber glow behind the symbol for depth
NSColor(red: 1.0, green: 0.72, blue: 0.1, alpha: 0.12).setFill()
NSBezierPath(ovalIn: NSRect(x: 162, y: 162, width: 700, height: 700)).fill()

// -- SF Symbol: bolt.circle.fill in amber ------------------------------------

let amberColor = NSColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 1.0)
let cfg = NSImage.SymbolConfiguration(pointSize: 580, weight: .medium)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: amberColor))

if let sym = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    sym.draw(in: NSRect(x: 222, y: 222, width: 580, height: 580),
             from: .zero, operation: .sourceOver, fraction: 0.97)
}

NSGraphicsContext.restoreGraphicsState()

// -- Export PNG --------------------------------------------------------------

guard let cgImage = ctx.makeImage() else {
    fputs("makeImage() failed\n", stderr); exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("PNG encoding failed\n", stderr); exit(1)
}
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("✓ icon_1024.png")
