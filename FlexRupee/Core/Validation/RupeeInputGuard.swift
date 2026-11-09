import Foundation

enum RupeeFieldLimit {
    static let mobileTyping = 11
    static let mobileSubmit = 10
    static let otpTyping = 6
    static let otpMinimum = 4
    static let whatsapp = 13
    static let childCount = 3
    static let ifsc = 11
    static let accountNo = 18
    static let creditCard = 32
    static let email = 128
    static let contactPhone = 13
    static let feedback = 1000
    static let aadhaar = 12
    static let pan = 10
    /// Loan / EMI principal — max ₹99,99,99,999 (TrustLoan: 8 digits).
    static let loanAmount = RupeeAmountFormat.maxLoanDigits
}

enum RupeeInputGuard {

    private static let indiaMobilePattern = #"^(0?)(910[6-9]\d{9}|91[6-9]\d{9}|0[6-9]\d{9}|[6-9]\d{9})$"#
    private static let emailPattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    private static let ifscPattern = #"^[A-Z]{4}0[A-Z0-9]{6}$"#
    private static let panPattern = #"^[A-Z]{5}[0-9]{4}[A-Z]$"#
    private static let aadhaarPattern = #"^\d{12}$"#

    static func digitsOnly(_ text: String) -> String {
        text.filter(\.isNumber)
    }

    static func matchesIndiaMobile(_ raw: String) -> Bool {
        let digits = digitsOnly(raw)
        // International `00…` must not pass as a trunk-`0` Indian mobile.
        if digits.hasPrefix("00") { return false }
        return evaluate(pattern: indiaMobilePattern, against: digits)
    }

    /// Strip only country/trunk prefixes `910` / `91` / `0` when length matches; never truncate otherwise.
    /// Does not strip `00…` (rejected by `matchesIndiaMobile`).
    static func normalizedIndiaMobile(_ raw: String) -> String {
        var digits = digitsOnly(raw)
        if digits.hasPrefix("00") { return digits }
        if digits.hasPrefix("910"), digits.count == 13 { digits.removeFirst(3) }
        else if digits.hasPrefix("91"), digits.count == 12 { digits.removeFirst(2) }
        else if digits.hasPrefix("0"), digits.count == 11 { digits.removeFirst() }
        return digits
    }

    static func isValidOTP(_ otp: String) -> Bool {
        let trimmed = otp.trimmingCharacters(in: .whitespaces)
        return trimmed.count == RupeeFieldLimit.otpTyping && trimmed.allSatisfy(\.isNumber)
    }

    static func matchesEmail(_ text: String) -> Bool {
        evaluate(pattern: emailPattern, against: text.trimmingCharacters(in: .whitespaces))
    }

    static func matchesIFSC(_ text: String) -> Bool {
        evaluate(pattern: ifscPattern, against: text.uppercased())
    }

    static func matchesPAN(_ text: String) -> Bool {
        evaluate(pattern: panPattern, against: text.uppercased())
    }

    static func matchesAadhaar(_ text: String) -> Bool {
        evaluate(pattern: aadhaarPattern, against: digitsOnly(text))
    }

    static func formattedAadhaar(_ raw: String) -> String {
        let digits = digitsOnly(raw)
        guard !digits.isEmpty else { return "-" }
        return stride(from: 0, to: digits.count, by: 4).map { offset in
            let start = digits.index(digits.startIndex, offsetBy: offset)
            let end = digits.index(start, offsetBy: min(4, digits.count - offset), limitedBy: digits.endIndex) ?? digits.endIndex
            return String(digits[start..<end])
        }.joined(separator: " ")
    }

    static func formattedPAN(_ raw: String) -> String {
        let value = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !value.isEmpty else { return "-" }
        return value
    }

    static func matchesServerRule(_ pattern: String?, text: String) -> Bool {
        guard let pattern, !pattern.isEmpty else { return !text.trimmingCharacters(in: .whitespaces).isEmpty }
        return evaluate(pattern: pattern, against: text)
    }

    static func clampLength(_ text: String, max: Int, digitsOnly: Bool = false) -> String {
        var value = digitsOnly ? self.digitsOnly(text) : text
        if value.count > max { value = String(value.prefix(max)) }
        return value
    }

    static func isAmountWithinRange(value: Int, floor: Int, ceiling: Int) -> Bool {
        value >= floor && value <= ceiling
    }

    private static func evaluate(pattern: String, against text: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: text)
    }
}
