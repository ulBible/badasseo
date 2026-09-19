import Foundation

/// Localization lookup — table `Localizable.xcstrings` in `Bundle.module`.
/// Korean is the source language (see `Resources/Localizable.xcstrings`), so
/// every call site passes the Korean text verbatim as the key; Korean output
/// is unaffected (Foundation returns the key itself when no translation is
/// needed), and an `"en"` localization is looked up when macOS runs in
/// English (including `-AppleLanguages '(en)'`).
@inline(__always)
func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }
