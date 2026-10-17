// Draws the app icon: macOS-style rounded square, Android-green gradient,
// a white phone with transfer arrows. Usage: swift make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background squircle (Big Sur icons leave ~10% margin and cast a soft shadow).
let inset: CGFloat = size * 0.095
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.03,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor(red: 0.16, green: 0.62, blue: 0.40, alpha: 1).setFill()
bg.fill()
ctx.restoreGState()
bg.addClip()
let gradient = NSGradient(colors: [
    NSColor(red: 0.30, green: 0.90, blue: 0.58, alpha: 1),
    NSColor(red: 0.12, green: 0.60, blue: 0.40, alpha: 1),
])!
gradient.draw(in: rect, angle: -90)
// Subtle top highlight.
let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
highlight.draw(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: 90)

// Phone body.
let phoneW = rect.width * 0.42, phoneH = rect.height * 0.70
let phone = CGRect(x: rect.midX - phoneW / 2, y: rect.midY - phoneH / 2, width: phoneW, height: phoneH)
let phonePath = NSBezierPath(roundedRect: phone, xRadius: phoneW * 0.14, yRadius: phoneW * 0.14)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.025,
              color: NSColor.black.withAlphaComponent(0.3).cgColor)
NSColor.white.setFill()
phonePath.fill()
ctx.restoreGState()
// Screen.
let screenInset = phoneW * 0.07
let screen = phone.insetBy(dx: screenInset, dy: screenInset * 1.6)
NSColor(red: 0.10, green: 0.16, blue: 0.14, alpha: 1).setFill()
NSBezierPath(roundedRect: screen, xRadius: phoneW * 0.08, yRadius: phoneW * 0.08).fill()
// Camera dot + speaker.
NSColor.white.withAlphaComponent(0.6).setFill()
NSBezierPath(ovalIn: CGRect(x: phone.midX - phoneW * 0.025, y: phone.maxY - screenInset * 1.1 - phoneW * 0.025,
                            width: phoneW * 0.05, height: phoneW * 0.05)).fill()

// Transfer arrows on the screen (SF Symbol).
let config = NSImage.SymbolConfiguration(pointSize: screen.width * 0.42, weight: .bold)
if let symbol = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size, flipped: false) { r in
        symbol.draw(in: r)
        NSColor(red: 0.30, green: 0.90, blue: 0.58, alpha: 1).set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = tinted.size
    let scale = (screen.width * 0.62) / max(s.width, s.height)
    let drawSize = NSSize(width: s.width * scale, height: s.height * scale)
    tinted.draw(in: NSRect(x: screen.midX - drawSize.width / 2, y: screen.midY - drawSize.height / 2,
                           width: drawSize.width, height: drawSize.height))
}
image.unlockFocus()

let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
