import Foundation

enum RupeeDeviceLocaleProbe {
    static func defaultLanguage() -> String {
        Locale.preferredLanguages.first?
            .split(separator: "-")
            .first
            .map(String.init) ?? ""
    }

    static func defaultTimeZone() -> String {
        TimeZone.current.identifier
    }
}
