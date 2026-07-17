import AppKit
import BadasseoAppKit
import Sparkle

// GitHub-release variant: Sparkle auto-updates, fed by appcast.xml on the
// GitHub "latest" release (SUFeedURL in Info.plist). Started eagerly so
// background update checks run on the interval Sparkle persists in user
// defaults. The Mac App Store variant (Sources/BadasseoAppStore) never sets
// badasseoCheckForUpdates — it stays nil there since that target doesn't
// link Sparkle at all (see Package.swift) — which hides the menu item.
let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
badasseoCheckForUpdates = { updaterController.updater.checkForUpdates() }

BadasseoRootApp.main()
