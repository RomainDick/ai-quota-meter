import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments[1]

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0, 0, 0, 0.35))
context.addPath(shape)
context.setFillColor(color(0.1, 0.1, 0.3))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(shape)
context.clip()
let background = CGGradient(colorsSpace: space, colors: [color(0.27, 0.29, 0.68), color(0.08, 0.09, 0.25)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
context.restoreGState()

let center = CGPoint(x: 512, y: 425)
let radius: CGFloat = 270
let startAngle: CGFloat = 200
let span: CGFloat = 220

func angle(_ fraction: CGFloat) -> CGFloat {
    (startAngle - span * fraction) * .pi / 180
}

func arc(from: CGFloat, to: CGFloat, stroke: CGColor, cap: CGLineCap) {
    context.beginPath()
    context.addArc(center: center, radius: radius, startAngle: angle(from), endAngle: angle(to), clockwise: true)
    context.setStrokeColor(stroke)
    context.setLineWidth(72)
    context.setLineCap(cap)
    context.strokePath()
}

arc(from: 0, to: 1, stroke: color(1, 1, 1, 0.12), cap: .round)
arc(from: 0.9, to: 1, stroke: color(0.96, 0.27, 0.3), cap: .round)
arc(from: 0, to: 0.7, stroke: color(0.2, 0.82, 0.45), cap: .round)
arc(from: 0.7, to: 0.9, stroke: color(1, 0.62, 0.1), cap: .butt)

let needle = angle(0.62)
context.beginPath()
context.move(to: center)
context.addLine(to: CGPoint(x: center.x + cos(needle) * 205, y: center.y + sin(needle) * 205))
context.setStrokeColor(color(1, 1, 1))
context.setLineWidth(28)
context.setLineCap(.round)
context.strokePath()

context.setFillColor(color(1, 1, 1))
context.fillEllipse(in: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))
context.setFillColor(color(0.12, 0.13, 0.36))
context.fillEllipse(in: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36))

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
