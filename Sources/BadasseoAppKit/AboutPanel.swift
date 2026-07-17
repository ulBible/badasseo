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
