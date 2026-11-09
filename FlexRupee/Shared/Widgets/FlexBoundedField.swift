import UIKit

protocol FlexBoundedFieldDelegate: AnyObject {
    func boundedFieldDidChange(_ field: FlexBoundedField)
}

final class FlexBoundedField: UITextField {
    enum InputMode {
        case plain(max: Int)
        case digits(max: Int)
        case uppercased(max: Int)
    }

    weak var boundedDelegate: FlexBoundedFieldDelegate?
    var inputMode: InputMode = .plain(max: 64)
    var validationRule: ((String) -> Bool)?
    var invalidHint: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Programmatic echo (e.g. Find IFSC) — keeps text visible beside the Find IFSC button.
    func echoText(_ value: String) {
        let font = self.font ?? FlexTypography.regular(15)
        attributedText = NSAttributedString(string: value, attributes: [
            .foregroundColor: FlexPalette.inkPrimary,
            .font: font
        ])
        textColor = FlexPalette.inkPrimary
        isUserInteractionEnabled = true
        setNeedsDisplay()
        layoutIfNeeded()
    }

    @discardableResult
    func validateSilently() -> Bool {
        let text = self.text ?? ""
        if let rule = validationRule, !rule(text) {
            if let hint = invalidHint, !hint.isEmpty {
                FlexToast.show(hint)
            }
            PulseBeaconRecorder.shared.stamp(.verifyFieldFail, note: invalidHint ?? text)
            return false
        }
        return true
    }

    @objc private func editingChanged() {
        boundedDelegate?.boundedFieldDidChange(self)
    }

    private func cap(for mode: InputMode) -> Int {
        switch mode {
        case .plain(let max), .digits(let max), .uppercased(let max): return max
        }
    }

    private func normalize(_ text: String, mode: InputMode) -> String {
        switch mode {
        case .plain(let max):
            return RupeeInputGuard.clampLength(text, max: max)
        case .digits(let max):
            return RupeeInputGuard.clampLength(text, max: max, digitsOnly: true)
        case .uppercased(let max):
            return RupeeInputGuard.clampLength(text.uppercased(), max: max)
        }
    }
}

extension FlexBoundedField: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty && range.length > 0 { return true }
        let current = textField.text ?? ""
        guard let swiftRange = Range(range, in: current) else { return false }
        let merged = current.replacingCharacters(in: swiftRange, with: string)
        let capped = normalize(merged, mode: inputMode)
        if capped != merged {
            textField.text = capped
            boundedDelegate?.boundedFieldDidChange(self)
            return false
        }
        return capped.count <= cap(for: inputMode)
    }

}
