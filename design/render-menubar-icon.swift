import AppKit

// 메뉴바 템플릿 아이콘 — 앱 아이콘과 동일한 심볼(마이크 좌 + 텍스트 라인 우)을
// 단색(검정, 투명 배경)으로 렌더. macOS가 라이트/다크·강조색에 맞춰 자동 틴트한다.
// 사용: swift render-menubar-icon.swift <출력디렉토리>  → menubar-icon.png(18pt)·menubar-icon@2x.png
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp"

func render(scale: CGFloat, lineCount: Int = 3) -> NSBitmapImageRep {
    let W: CGFloat = 22 * scale, H: CGFloat = 18 * scale   // 메뉴바 관례: 약간 넓은 캔버스
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let S = H                                             // 심볼 기준 치수 = 높이
    ctx.setFillColor(.black)
    ctx.setStrokeColor(.black)
    ctx.setLineCap(.round)

    // 마이크 (앱 아이콘과 같은 비율, 캔버스에 맞게 스케일)
    let micCx = S*0.34
    let micW = S*0.30, micH = S*0.48
    let headTop = S*0.92
    let body = CGRect(x: micCx - micW/2, y: headTop - micH, width: micW, height: micH)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: micW/2, cornerHeight: micW/2, transform: nil))
    ctx.fillPath()
    let arcR = S*0.27
    let arcCY = headTop - micH*0.72
    ctx.setLineWidth(S*0.09)
    ctx.addArc(center: CGPoint(x: micCx, y: arcCY), radius: arcR,
               startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()
    let arcBottom = arcCY - arcR
    ctx.move(to: CGPoint(x: micCx, y: arcBottom)); ctx.addLine(to: CGPoint(x: micCx, y: arcBottom - S*0.10))
    ctx.strokePath()

    // 텍스트 라인(우측, 3줄 문단 — 앱 아이콘과 동일 구성) — 마이크 뭉치 세로 중앙 기준
    let textX = micCx + arcR + S*0.14
    let rowMid = (headTop + (arcBottom - S*0.10)) / 2
    ctx.setLineWidth(S*0.095)
    let full = W - S*0.06 - textX
    let rowGap = S*0.24
    for (i, frac) in [1.0, 0.72, 0.45].enumerated() where i < lineCount {
        let y = rowMid + rowGap - CGFloat(i) * rowGap
        ctx.move(to: CGPoint(x: textX, y: y))
        ctx.addLine(to: CGPoint(x: textX + full * frac, y: y))
        ctx.strokePath()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (scale, suffix) in [(CGFloat(1), ""), (CGFloat(2), "@2x")] {
    // 평상시 아이콘(3줄 완성형)
    let full = render(scale: scale)
    try! full.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/menubar-icon\(suffix).png"))
    print("wrote \(outDir)/menubar-icon\(suffix).png")
    // 변환 중 애니메이션 프레임: 0줄→1줄→2줄→3줄 (타이핑되는 느낌)
    for n in 0...3 {
        let rep = render(scale: scale, lineCount: n)
        try! rep.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: "\(outDir)/menubar-frame\(n)\(suffix).png"))
        print("wrote \(outDir)/menubar-frame\(n)\(suffix).png")
    }
}
