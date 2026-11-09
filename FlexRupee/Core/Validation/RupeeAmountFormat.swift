import Foundation

/// Indian locale amount formatting — aligned with TrustLoan `tl_indianFormattedAmount`.
enum RupeeAmountFormat {
    private static let locale = Locale(identifier: "en_IN")

    /// Max raw digits for loan / EMI principal (₹99,99,99,999).
    static let maxLoanDigits = 8

    static let maxLoanValue = 99_999_999

    static func digits(from raw: String?) -> String {
        (raw ?? "").filter(\.isNumber)
    }

    /// Keep digits and at most one decimal point; strip ₹ / commas / spaces.
    private static func numericToken(from raw: String?) -> String {
        var token = ""
        var seenDot = false
        for ch in raw ?? "" {
            if ch.isNumber {
                token.append(ch)
            } else if ch == ".", !seenDot {
                token.append(ch)
                seenDot = true
            }
        }
        return token
    }

    static func indian(_ raw: String?, fractionDigits: Int = 0) -> String {
        let cleaned = numericToken(from: raw)
        guard !cleaned.isEmpty, let number = Double(cleaned) else { return raw ?? "" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        return formatter.string(for: NSNumber(value: number)) ?? cleaned
    }

    static func rupee(_ raw: String?, fractionDigits: Int = 0) -> String {
        "₹\(indian(raw, fractionDigits: fractionDigits))"
    }

    /// Detail header amount — design uses a space after ₹.
    static func rupeeSpaced(_ raw: String?, fractionDigits: Int = 0) -> String {
        "₹ \(indian(raw, fractionDigits: fractionDigits))"
    }

    static func rupeeDecimal(_ value: Double) -> String {
        rupee(String(format: "%.2f", value), fractionDigits: 2)
    }

    static func range(low: String?, high: String?) -> String {
        "\(rupee(low)) - \(rupee(high))"
    }

    static func clampLoanDigits(_ raw: String?) -> String {
        String(digits(from: raw).prefix(maxLoanDigits))
    }

    static func clampLoanValue(_ raw: String?) -> String {
        let digits = clampLoanDigits(raw)
        guard let value = Int(digits) else { return digits }
        return "\(min(value, maxLoanValue))"
    }
}
