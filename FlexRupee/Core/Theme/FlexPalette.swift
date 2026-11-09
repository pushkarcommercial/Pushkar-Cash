import UIKit

enum FlexPalette {
    /// Primary brand — cards, Apply buttons (#4A768C).
    static let primaryTeal = UIColor(hex: 0x4A768C)
    /// Legacy alias used across the app.
    static let mintTeal = primaryTeal

    /// Accent green — check-in, rate pill, active tab (#8CCF91).
    static let accentGreen = UIColor(hex: 0x8CCF91)
    static let sproutGreen = accentGreen

    /// Screen background (#F4F7F8).
    static let canvasGray = UIColor(hex: 0xF4F7F8)
    static let cardWhite = UIColor.white

    /// KYC / status banner (#E9EEF2).
    static let bannerGray = UIColor(hex: 0xE9EEF2)

    static let dockBlack = UIColor.black
    static let dockIdle = UIColor(hex: 0x1A1A1A)

    static let inkPrimary = UIColor(hex: 0x1A1A1A)
    static let inkSecondary = UIColor(hex: 0x6B7280)
    static let inkTertiary = UIColor(hex: 0x9AA3AD)
    static let inkPlaceholder = UIColor(hex: 0xC4C9CF)

    static let dangerRose = UIColor(hex: 0xFF3B30)
    static let warnAmber = UIColor(hex: 0xFF9500)
    static let splashNavy = UIColor(hex: 0x1E2A3A)
    static let fieldBorder = UIColor(hex: 0xE2E6EA)
    static let logoTile = primaryTeal

    /// Home loan-banner amount (#F5C518).
    static let loanGold = UIColor(hex: 0xF5C518)
}
