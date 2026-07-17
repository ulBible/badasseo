import AppKit

// 받아써 앱 아이콘 G — 마이크 + 텍스트 라인, 그린 스퀘어클. 1024pt 마스터 렌더.
let S: CGFloat = 1024
let rect = CGRect(x: 0, y: 0, width: S, height: S)

let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// 배경: 스퀘어클(연속 곡률 근사) + 155° 그린 그라데이션
let inset: CGFloat = S * 0.06                      // 아이콘 세이프 여백
let bg = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let corner = bg.width * 0.235                       // Big Sur 스퀘어클 비율
let bgPath = CGPath(roundedRect: bg, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 0.278, green: 0.886, blue: 0.431, alpha: 1),  // #47e26e
    CGColor(red: 0.039, green: 0.518, blue: 0.039, alpha: 1),  // #0a840a
] as CFArray, locations: [0, 1])!
// 155°: 좌상단 → 우하단 근처
ctx.drawLinearGradient(grad, start: CGPoint(x: bg.minX, y: bg.maxY),
                       end: CGPoint(x: bg.maxX, y: bg.minY*1.0 + bg.height*0.05), options: [])
// 상단 내부 하이라이트
let hi = CGGradient(colorsSpace: cs, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.22), CGColor(red: 1, green: 1, blue: 1, alpha: 0)
] as CFArray, locations: [0, 0.45])!
ctx.drawLinearGradient(hi, start: CGPoint(x: bg.midX, y: bg.maxY),
                       end: CGPoint(x: bg.midX, y: bg.midY), options: [])
ctx.restoreGState()

// 심볼(흰색): 마이크 + 텍스트 라인. 중앙 정렬 좌표(아이콘 논리 좌표)
let cx = S/2
ctx.setFillColor(.white)
ctx.setStrokeColor(.white)
ctx.setLineCap(.round)

// ── 상단 구역: 마이크 (헤드 + 받침 + 스탠드) — 원래 형태 그대로 ──
let micW: CGFloat = S*0.125, micH: CGFloat = S*0.205
let micHeadTop = S*0.82                             // 마이크 뭉치를 위쪽에 배치
let micBody = CGRect(x: cx - micW/2, y: micHeadTop - micH, width: micW, height: micH)
ctx.addPath(CGPath(roundedRect: micBody, cornerWidth: micW/2, cornerHeight: micW/2, transform: nil))
ctx.fillPath()

// 받침 아크(U자) — 헤드를 감싸는 원래 비율
let arcR = S*0.115
let arcCenterY = micHeadTop - micH*0.72
ctx.setLineWidth(S*0.036)
ctx.addArc(center: CGPoint(x: cx, y: arcCenterY), radius: arcR,
           startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
ctx.strokePath()
let arcBottom = arcCenterY - arcR                  // 마이크 최하단
// 스탠드(짧게)
ctx.move(to: CGPoint(x: cx, y: arcBottom)); ctx.addLine(to: CGPoint(x: cx, y: arcBottom - S*0.04))
ctx.strokePath()

// ── 하단 구역: 텍스트 입력 (긴 줄 + 짧은 줄 + 커서) ──
// 마이크 최하단(스탠드 포함)과 충분한 간격을 두고 배치
let gap = S*0.11                                   // ← 마이크 뭉치 ↔ 텍스트 뭉치 간격만 넓게
let row1 = (arcBottom - S*0.04) - gap              // 긴 줄
let row2 = row1 - S*0.075                           // 짧은 줄
let leftX = cx - S*0.155
ctx.setLineWidth(S*0.034)
ctx.move(to: CGPoint(x: leftX, y: row1)); ctx.addLine(to: CGPoint(x: cx + S*0.11, y: row1))
ctx.strokePath()
let shortEnd = cx - S*0.02
ctx.move(to: CGPoint(x: leftX, y: row2)); ctx.addLine(to: CGPoint(x: shortEnd, y: row2))
ctx.strokePath()
// 커서: 짧은 줄 바로 뒤
let cur = CGRect(x: shortEnd + S*0.026, y: row2 - S*0.036, width: S*0.026, height: S*0.082)
ctx.addPath(CGPath(roundedRect: cur, cornerWidth: S*0.011, cornerHeight: S*0.011, transform: nil))
ctx.fillPath()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("render failed\n".data(using: .utf8)!); exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/badasseo-icon-1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
