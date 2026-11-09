import Foundation

/// EMI calculator bounds — aligned with P20 / product spec (1–1Cr, 1–25yr, 1–22%).
enum RupeeEMILimits {
    static let minAmount: Double = 1
    static let maxAmount: Double = 10_000_000
    static let maxAmountDigits = 8

    static let minYears = 1
    static let maxYears = 25

    static let minRate: Double = 1
    static let maxRate: Double = 22
    static let maxRateChars = 5

    static let defaultAmount = "50000"
    static let defaultYears = "5"
    static let defaultRate = "3"

    static let amountChips = ["10000", "50000", "100000", "500000"]
    static let yearChips = ["5", "10", "15", "20"]
    static let rateChips = ["2", "8", "12", "16"]
}

enum RupeeEMIInputGuard {
    static func digits(from raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func isValidAmount(_ text: String) -> Bool {
        let digits = digits(from: text)
        if digits.isEmpty { return true }
        if digits.count > RupeeEMILimits.maxAmountDigits { return false }
        guard let value = Double(digits) else { return false }
        return value <= RupeeEMILimits.maxAmount
    }

    static func amountReadyForSubmit(_ text: String) -> Bool {
        let digits = digits(from: text)
        guard !digits.isEmpty, let value = Double(digits) else { return false }
        return value >= RupeeEMILimits.minAmount && value <= RupeeEMILimits.maxAmount
    }

    static func clampAmount(_ raw: String) -> String {
        var digits = String(digits(from: raw).prefix(RupeeEMILimits.maxAmountDigits))
        if let value = Double(digits), value > RupeeEMILimits.maxAmount {
            digits = "\(Int(RupeeEMILimits.maxAmount))"
        }
        return digits
    }

    static func finalizeAmount(_ raw: String) -> String {
        let digits = clampAmount(raw)
        guard !digits.isEmpty else { return "" }
        let value = Double(digits) ?? 0
        if value < RupeeEMILimits.minAmount { return "1" }
        if value > RupeeEMILimits.maxAmount { return "\(Int(RupeeEMILimits.maxAmount))" }
        return RupeeAmountFormat.indian("\(Int(value))")
    }

    static func isValidYears(_ text: String) -> Bool {
        if text.isEmpty { return true }
        if text.count > 2 { return false }
        guard text.allSatisfy(\.isNumber), let value = Int(text) else { return false }
        return (RupeeEMILimits.minYears...RupeeEMILimits.maxYears).contains(value)
    }

    static func yearsReadyForSubmit(_ text: String) -> Bool {
        guard !text.isEmpty, let value = Int(text) else { return false }
        return (RupeeEMILimits.minYears...RupeeEMILimits.maxYears).contains(value)
    }

    static func clampYears(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(2))
    }

    static func finalizeYears(_ raw: String) -> String {
        let digits = clampYears(raw)
        guard !digits.isEmpty else { return "" }
        let value = Int(digits) ?? 0
        if value < RupeeEMILimits.minYears { return "\(RupeeEMILimits.minYears)" }
        if value > RupeeEMILimits.maxYears { return "\(RupeeEMILimits.maxYears)" }
        return "\(value)"
    }

    static func isValidRate(_ text: String) -> Bool {
        if text.isEmpty { return true }
        if text == "." { return true }
        if text.count > RupeeEMILimits.maxRateChars { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.")
        if text.unicodeScalars.contains(where: { !allowed.contains($0) }) { return false }
        if text.filter({ $0 == "." }).count > 1 { return false }
        if let dot = text.firstIndex(of: ".") {
            if text[text.index(after: dot)...].count > 2 { return false }
        }
        if let value = Double(text) { return (0...RupeeEMILimits.maxRate).contains(value) }
        return false
    }

    static func rateReadyForSubmit(_ text: String) -> Bool {
        guard !text.isEmpty, let value = Double(text) else { return false }
        return value >= RupeeEMILimits.minRate && value <= RupeeEMILimits.maxRate
    }

    static func sanitizeRate(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        if raw == "." { return "." }
        var out = ""
        var hasDot = false
        var decimalCount = 0
        for ch in raw {
            if ch.isNumber {
                if hasDot {
                    if decimalCount >= 2 { continue }
                    decimalCount += 1
                }
                out.append(ch)
                continue
            }
            if ch == ".", !hasDot {
                hasDot = true
                out.append(ch)
            }
        }
        if out.count > RupeeEMILimits.maxRateChars { out = String(out.prefix(RupeeEMILimits.maxRateChars)) }
        if let value = Double(out), value > RupeeEMILimits.maxRate { return "22" }
        return out
    }

    static func finalizeRate(_ raw: String) -> String {
        let sanitized = sanitizeRate(raw)
        guard !sanitized.isEmpty else { return "" }
        let value = Double(sanitized) ?? 0
        if value < RupeeEMILimits.minRate { return "1" }
        if value > RupeeEMILimits.maxRate { return "22" }
        if sanitized.contains(".") { return sanitized }
        return "\(Int(value))"
    }
}

struct RupeeEMIResult {
    let principal: Double
    let years: Double
    let annualRate: Double
    let monthlyEMI: Double
    let totalPayment: Double
    let totalInterest: Double
}
