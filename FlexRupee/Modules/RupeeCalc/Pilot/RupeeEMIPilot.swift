import Foundation
import RxSwift

final class RupeeEMIPilot {
    static func compute(principal: Double, years: Double, annualRate: Double) -> RupeeEMIResult? {
        guard principal > 0, years > 0, annualRate >= 0 else { return nil }
        let months = years * 12
        let monthlyRate = annualRate / 100 / 12
        let factor = pow(1 + monthlyRate, months)
        let emi = monthlyRate == 0 ? principal / months : principal * monthlyRate * factor / (factor - 1)
        let total = emi * months
        return RupeeEMIResult(principal: principal,
                                years: years,
                                annualRate: annualRate,
                                monthlyEMI: emi,
                                totalPayment: total,
                                totalInterest: total - principal)
    }
}
