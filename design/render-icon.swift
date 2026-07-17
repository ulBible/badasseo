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

// 심볼(흰색): 마이크(좌) + 텍스트 라인(우) 가로 배치, 그룹 전체를 중앙 정렬
let cy = S/2
ctx.setFillColor(.white)
ctx.setStrokeColor(.white)
ctx.setLineCap(.round)

// ── 좌측: 마이크 (헤드 + 받침 아크 + 스탠드) ──
let micCx = S*0.345                                 // 마이크 축
let micW: CGFloat = S*0.15, micH: CGFloat = S*0.27  // 헤드를 더 길고 크게
let micHeadTop = cy + S*0.205                       // 마이크 뭉치를 수직 중앙에
let micBody = CGRect(x: micCx - micW/2, y: micHeadTop - micH, width: micW, height: micH)
ctx.addPath(CGPath(roundedRect: micBody, cornerWidth: micW/2, cornerHeight: micW/2, transform: nil))
ctx.fillPath()

// 받침 아크(U자)
let arcR = S*0.14
let arcCenterY = micHeadTop - micH*0.72
ctx.setLineWidth(S*0.042)
ctx.addArc(center: CGPoint(x: micCx, y: arcCenterY), radius: arcR,
           startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
ctx.strokePath()
let arcBottom = arcCenterY - arcR                  // 마이크 최하단
// 스탠드(짧게)
ctx.move(to: CGPoint(x: micCx, y: arcBottom)); ctx.addLine(to: CGPoint(x: micCx, y: arcBottom - S*0.05))
ctx.strokePath()

// ── 우측: 텍스트 입력 (긴 줄 + 짧은 줄 + 커서) — 마이크 헤드 높이에 맞춤 ──
let textX = micCx + arcR + S*0.075                 // 아크 우측 끝에서 간격을 두고 시작
// 마이크 뭉치 전체(헤드 상단~스탠드 하단)의 세로 중앙에 텍스트 블록을 맞춘다
let micBottom = arcBottom - S*0.05
let rowMid = (micHeadTop + micBottom) / 2
// 3줄, 오른쪽 끝이 들쭉날쭉한 문단 느낌 (커서 없음)
ctx.setLineWidth(S*0.036)
let rowGap = S*0.092
for (i, len) in [S*0.21, S*0.165, S*0.115].enumerated() {
    let y = rowMid + rowGap - CGFloat(i) * rowGap
    ctx.move(to: CGPoint(x: textX, y: y)); ctx.addLine(to: CGPoint(x: textX + len, y: y))
    ctx.strokePath()
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("render failed\n".data(using: .utf8)!); exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/badasseo-icon-1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
