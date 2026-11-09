import Foundation

/// Order list / ledger date display — design target: `Sep 28, 2025`.
enum RupeeDateFormat {
    private static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let parsers: [(DateFormatter, Set<String>)] = {
        let specs: [(String, Set<String>)] = [
            ("yyyy-MM-dd HH:mm:ss", ["yyyy-MM-dd HH:mm:ss"]),
            ("yyyy-MM-dd", ["yyyy-MM-dd"]),
            ("yyyy/MM/dd HH:mm:ss", ["yyyy/MM/dd HH:mm:ss"]),
            ("yyyy/MM/dd", ["yyyy/MM/dd"]),
            ("MMM d, yyyy", ["MMM d, yyyy"]),
            ("MMM dd, yyyy", ["MMM dd, yyyy"])
        ]
        return specs.map { pattern, formats in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            return (formatter, formats)
        }
    }()

    static func ledgerDisplay(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != "-" else { return "-" }

        if let date = parse(trimmed) {
            return output.string(from: date)
        }
        return trimmed
    }

    private static func parse(_ text: String) -> Date? {
        if text.allSatisfy(\.isNumber), text.count >= 10, let millis = Double(text) {
            let seconds = text.count > 10 ? millis / 1000 : millis
            let date = Date(timeIntervalSince1970: seconds)
            if date.timeIntervalSince1970 > 0 { return date }
        }

        for (formatter, _) in parsers {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
