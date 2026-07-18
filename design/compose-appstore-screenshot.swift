import AppKit

// App Store 스크린샷 합성기 (vClips 패턴): 2880×1800 그라데이션 + 헤드라인 + 창 캡처.
// 인자: <창PNG> <출력PNG> <헤드라인> <서브헤드> [창스케일=1.0]
let args = CommandLine.arguments
guard args.count >= 5 else { FileHandle.standardError.write("usage: compose <win.png> <out.png> <headline> <sub> [scale]\n".data(using: .utf8)!); exit(1) }
let winPath = args[1], outPath = args[2], headline = args[3], sub = args[4]
let scale = args.count > 5 ? CGFloat(Double(args[5]) ?? 1.0) : 1.0

let W: CGFloat = 2880, H: CGFloat = 1800
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// 배경: 받아써 그린 그라데이션 (아이콘·온보딩 톤 — 좌상 밝음 → 우하 짙음)
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.176, green: 0.62, blue: 0.29, alpha: 1),   // #2d9e4a 밝은 그린
    CGColor(red: 0.031, green: 0.36, blue: 0.086, alpha: 1),  // #085c16 짙은 그린
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
// 은은한 비네트(아래쪽 살짝 어둡게)
let vin = CGGradient(colorsSpace: cs, colors: [
    CGColor(gray: 0, alpha: 0.0), CGColor(gray: 0, alpha: 0.18)
] as CFArray, locations: [0.55, 1])!
ctx.drawLinearGradient(vin, start: CGPoint(x: W/2, y: H), end: CGPoint(x: W/2, y: 0), options: [])

// 텍스트
func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let a: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: p,
    ]
    let str = NSAttributedString(string: s, attributes: a)
    let sz = str.size()
    str.draw(at: NSPoint(x: (W - sz.width)/2, y: y))
}
draw(headline, size: 118, weight: .bold, color: .white, y: H - 330)
draw(sub, size: 52, weight: .regular, color: NSColor.white.withAlphaComponent(0.82), y: H - 435)

// 창 캡처 (알파 코너 보존) + 부드러운 그림자
guard let win = NSImage(contentsOfFile: winPath) else { FileHandle.standardError.write("cannot load \(winPath)\n".data(using: .utf8)!); exit(1) }
let rep = win.representations.first!
let pw = CGFloat(rep.pixelsWide), ph = CGFloat(rep.pixelsHigh)
let dw = pw * scale, dh = ph * scale
let x = (W - dw)/2
let yTop = H - 520                                  // 서브헤드 아래에서 시작
let y = max(60, yTop - dh)                          // 하단 여백 최소 60
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
shadow.shadowBlurRadius = 44
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
win.draw(in: NSRect(x: x, y: y, width: dw, height: dh),
         from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.current?.restoreGraphicsState()

img.unlockFocus()
guard let tiff = img.tiffRepresentation, let bm = NSBitmapImageRep(data: tiff) else { exit(1) }
bm.size = NSSize(width: W, height: H)   // 1x 포인트=픽셀 (2880×1800 정확히)
guard let png = bm.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
