import ContactsUI
import UIKit

final class RupeeContactPickerCoordinator: NSObject {
    private var onPick: ((String, String) -> Void)?
    private var onCancel: (() -> Void)?

    func present(from host: UIViewController,
                 onPick: @escaping (String, String) -> Void,
                 onCancel: (() -> Void)? = nil) {
        self.onPick = onPick
        self.onCancel = onCancel
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == %@", CNContactPhoneNumbersKey)
        host.present(picker, animated: true)
    }
}

extension RupeeContactPickerCoordinator: CNContactPickerDelegate {
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onCancel?()
    }

    /// Pass raw name + phone only — host validates after the picker dismisses
    /// so toasts appear on the emergency-contact page, not over the address book.
    func contactPicker(_ picker: CNContactPickerViewController,
                       didSelect contactProperty: CNContactProperty) {
        guard contactProperty.key == CNContactPhoneNumbersKey,
              let phoneNumber = contactProperty.value as? CNPhoneNumber else { return }

        let contact = contactProperty.contact
        let name = [contact.givenName, contact.middleName, contact.familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let fallback = (CNContactFormatter.string(from: contact, style: .fullName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? fallback : name
        onPick?(resolvedName, phoneNumber.stringValue)
    }
}
