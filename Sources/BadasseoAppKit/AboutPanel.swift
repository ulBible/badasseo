import AppKit

/// The standard About panel with Chakchak Works credits. The system draws
/// the icon, app name, version (CFBundleShortVersionString), and copyright
/// (NSHumanReadableCopyright); we only supply the credits block. The Mac
/// App Store build hides the Support link (App Review guideline 3.1.1).
@MainActor
enum AboutPanel {
    static func show(showsSupportLink: Bool) {
        // LSUIElement accessory: activate first or the panel opens behind
        // the user's current app (same caveat as Settings).
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits(showsSupportLink: showsSupportLink)
        ])
    }

    /// The Chakchak Works snap mark — identical drawing to vClips' AboutPanel
    /// so the studio identity matches across apps. Drawn with dynamic colors
    /// via a drawing handler so it re-renders correctly in light and dark
    /// (the ink block follows labelColor; the incoming block stays brand blue).
    private static func markImage() -> NSImage {
        let size = NSSize(width: 132, height: 70)
        return NSImage(size: size, flipped: false) { _ in
            let ink = NSColor.labelColor
            let glyph = NSColor.windowBackgroundColor
            let blue = NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.96, alpha: 1)

            func stroke(_ a: NSPoint, _ b: NSPoint, _ w: CGFloat, _ c: NSColor) {
                c.setStroke()
                let p = NSBezierPath()
                p.lineWidth = w
                p.lineCapStyle = .round
                p.move(to: a); p.line(to: b)
                p.stroke()
            }
            // stylized ㅊ, a little figure; legStride > 0 makes it stride
            func chi(at c: NSPoint, scale s: CGFloat, color: NSColor, legStride: CGFloat) {
                let lw = s * 0.16
                stroke(NSPoint(x: c.x - s * 0.10, y: c.y + s * 0.46),
                       NSPoint(x: c.x + s * 0.14, y: c.y + s * 0.52), lw, color)
                stroke(NSPoint(x: c.x - s * 0.34, y: c.y + s * 0.18),
                       NSPoint(x: c.x + s * 0.34, y: c.y + s * 0.18), lw, color)
                let hip = NSPoint(x: c.x, y: c.y + s * 0.16)
                stroke(hip, NSPoint(x: c.x - s * (0.30 + legStride), y: c.y - s * (legStride > 0 ? 0.44 : 0.50)), lw, color)
                stroke(hip, NSPoint(x: c.x + s * (0.30 + legStride), y: c.y - s * 0.50), lw, color)
            }

            let blockW: CGFloat = 36, blockH: CGFloat = 46, radius: CGFloat = 9, gap: CGFloat = 7
            let y0: CGFloat = 8
            let left = NSRect(x: 10, y: y0, width: blockW, height: blockH)
            ink.setFill()
            NSBezierPath(roundedRect: left, xRadius: radius, yRadius: radius).fill()
            chi(at: NSPoint(x: left.midX, y: left.midY), scale: 24, color: glyph, legStride: 0)

            let right = NSRect(x: left.maxX + gap, y: y0 + 2, width: blockW, height: blockH)
            NSGraphicsContext.current?.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: right.midX, yBy: right.midY)
            t.rotate(byDegrees: -9)
            t.translateX(by: -right.midX, yBy: -right.midY)
            t.concat()
            blue.setFill()
            NSBezierPath(roundedRect: right, xRadius: radius, yRadius: radius).fill()
            chi(at: NSPoint(x: right.midX, y: right.midY), scale: 24, color: .white, legStride: 0.16)
            NSGraphicsContext.current?.restoreGraphicsState()

            let mx = right.maxX + 8
            for (dy, len) in [(12, 8), (23, 12), (34, 8)] as [(CGFloat, CGFloat)] {
                stroke(NSPoint(x: mx, y: y0 + dy), NSPoint(x: mx + len, y: y0 + dy + 1),
                       2.6, ink.withAlphaComponent(0.45))
            }
            return true
        }
    }

    private static func credits(showsSupportLink: Bool) -> NSAttributedString {
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        center.lineSpacing = 2

        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: center,
        ]
        let secondary: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: center,
        ]

        func link(_ title: String, _ url: String) -> NSAttributedString {
            var attrs = body
            attrs[.link] = URL(string: url)!
            return NSAttributedString(string: title, attributes: attrs)
        }

        let text = NSMutableAttributedString()
        let attachment = NSTextAttachment()
        attachment.image = markImage()
        attachment.bounds = CGRect(x: 0, y: 0, width: 132, height: 70)
        let mark = NSMutableAttributedString(attachment: attachment)
        mark.addAttribute(.paragraphStyle, value: center,
                          range: NSRange(location: 0, length: mark.length))
        text.append(mark)
        text.append(NSAttributedString(string: "\n", attributes: secondary))
        text.append(NSAttributedString(
            string: "키보드 대신 말로. 전 과정이 내 맥 안에서.\n", attributes: body))
        text.append(NSAttributedString(
            string: "Made by Chakchak Works · by ulBible\n\n", attributes: secondary))

        let separator = NSAttributedString(string: "  ·  ", attributes: secondary)
        text.append(link("GitHub", "https://github.com/ulBible/badasseo"))
        if showsSupportLink {
            text.append(separator)
            text.append(link("Support ❤️", "https://github.com/sponsors/ulBible"))
        }
        text.append(separator)
        text.append(link("Privacy Policy",
                         "https://github.com/ulBible/badasseo/blob/main/PRIVACY.md"))
        return text
    }
}
