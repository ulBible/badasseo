import BadasseoAppKit

// Mac App Store variant: sandboxed, no Sparkle (the store owns updates —
// this target doesn't even link Sparkle, see Package.swift). Explicitly nil
// here for clarity, though it's also the default.
badasseoCheckForUpdates = nil

BadasseoRootApp.main()
