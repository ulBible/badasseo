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

    /// The Chakchak Works mark — identical drawing to vClips' AboutPanel so the
    /// studio identity matches across apps: the last blue block being set into
    /// the empty top-right slot of a 2×2 stack (착착: blocks snapping into
    /// place), drawn with dynamic colors via a drawing handler so it re-renders
    /// correctly in light or dark (seated blocks follow labelColor; the
    /// incoming block stays brand blue).
    private static func markImage() -> NSImage {
        let size = NSSize(width: 57, height: 63)
        return NSImage(size: size, flipped: false) { rect in
            let ink = NSColor.labelColor
            let blue = NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.96, alpha: 1)
            // The design grid is 100×110 with top-down y, scaled into the view.
            let u = min(rect.width / 100, rect.height / 110)
            let ox = (rect.width - 100 * u) / 2
            let oy = (rect.height - 110 * u) / 2

            func block(_ x: CGFloat, _ yTop: CGFloat) -> NSBezierPath {
                let r = NSRect(x: ox + x * u, y: oy + (80 - yTop) * u,
                               width: 30 * u, height: 30 * u)
                return NSBezierPath(roundedRect: r, xRadius: 8 * u, yRadius: 8 * u)
            }
            func trail(_ x: CGFloat, _ y1: CGFloat, _ y2: CGFloat) {
                ink.withAlphaComponent(0.45).setStroke()
                let p = NSBezierPath()
                p.lineWidth = 2.8 * u
                p.lineCapStyle = .round
                p.move(to: NSPoint(x: ox + x * u, y: oy + y1 * u))
                p.line(to: NSPoint(x: ox + x * u, y: oy + y2 * u))
                p.stroke()
            }

            ink.setFill()
            block(18, 44).fill()
            block(18, 78).fill()
            block(52, 78).fill()

            let slot = block(52, 44)          // the waiting slot, a hairline
            slot.lineWidth = 1.3 * u
            ink.withAlphaComponent(0.3).setStroke()
            slot.stroke()

            NSGraphicsContext.current?.saveGraphicsState()
            let cx = ox + 67 * u, cy = oy + 77 * u
            let t = NSAffineTransform()
            t.translateX(by: cx, yBy: cy)
            t.rotate(byDegrees: 8)
            t.translateX(by: -cx, yBy: -cy)
            t.concat()
            blue.setFill()
            block(52, 18).fill()              // descending, leading corner first
            NSGraphicsContext.current?.restoreGraphicsState()

            trail(77, 101, 108)
            trail(86, 97, 104)
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
        // Lift the mark above the baseline — the drawing runs nearly to the
        // image's bottom edge, so without this the tagline sits too close.
        // The credits area has a fixed height and scrolls past it, so the
        // lift is paid for by a slightly smaller mark and by replacing the
        // blank line before the links with paragraphSpacing below.
        attachment.bounds = CGRect(x: 0, y: 16, width: 57, height: 63)
        let mark = NSMutableAttributedString(attachment: attachment)
        mark.addAttribute(.paragraphStyle, value: center,
                          range: NSRange(location: 0, length: mark.length))
        text.append(mark)
        text.append(NSAttributedString(string: "\n", attributes: secondary))
        text.append(NSAttributedString(
            string: "키보드 대신 말로. 전 과정이 내 맥 안에서.\n", attributes: body))
        let creditGap = NSMutableParagraphStyle()
        creditGap.alignment = .center
        creditGap.lineSpacing = 2
        creditGap.paragraphSpacing = 6
        var creditAttrs = secondary
        creditAttrs[.paragraphStyle] = creditGap
        text.append(NSAttributedString(
            string: "Made by Chakchak Works · by ulBible\n", attributes: creditAttrs))

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
