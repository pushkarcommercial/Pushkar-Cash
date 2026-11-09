import AddressBook
import Contacts
import Foundation

enum RupeeContactOutcome {
    case uploaded
    case skippedWeakMode
    /// Contacts denied/restricted on retry — show custom sheet.
    case needsSettingsPrompt
    /// First system prompt has not been shown yet.
    case notDetermined
    /// Limited/partial access counts as unauthorized — leave product detail immediately.
    case partialUnauthorized
    case aborted
}

final class RupeeContactHarvester {
    static let shared = RupeeContactHarvester()

    /// Empty-book placeholder used when no valid Indian mobiles are found.
    private static let placeholderRow: [String: String] = [
        "contactName": "",
        "contactPhone": "9876543210",
        "contactUpdateTime": "",
        "contactStorage": "1",
        "contactCount": "-99",
        "contactTime": ""
    ]

    private init() {}

    func evaluateAccess(strict: Bool) -> RupeeContactOutcome {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            PulseBeaconRecorder.shared.stamp(.contactsGranted)
            return .uploaded
        case .limited:
            PulseBeaconRecorder.shared.stamp(.contactsLimited)
            return strict ? .needsSettingsPrompt : .skippedWeakMode
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            PulseBeaconRecorder.shared.stamp(.contactsDenied)
            return strict ? .needsSettingsPrompt : .skippedWeakMode
        @unknown default:
            return .aborted
        }
    }

    func requestSystemAccess(completion: @escaping (Bool) -> Void) {
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Collects contacts for `/mobile/contact` — Indian mobile rules + real `contactUpdateTime`.
    /// Modification time comes from AddressBook (`kABPersonModificationDateProperty`), same source Kiva uses.
    func buildPayload(limit: Int) -> [[String: String]] {
        let cap = max(0, limit)
        guard cap > 0 else { return [Self.placeholderRow] }

        guard let book = ABAddressBookCreateWithOptions(nil, nil)?.takeRetainedValue(),
              let people = ABAddressBookCopyArrayOfAllPeople(book)?.takeRetainedValue() as? [ABRecord] else {
            return [Self.placeholderRow]
        }

        var rows: [[String: String]] = []
        var seenPhones = Set<String>()

        for person in people {
            // Empty name is allowed — still upload when the phone is a valid Indian mobile.
            let name = Self.displayName(from: person)
            let revisedMs = Self.modificationMillis(from: person)
            for raw in Self.phoneNumbers(from: person) {
                guard RupeeInputGuard.matchesIndiaMobile(raw) else { continue }
                let phone = RupeeInputGuard.normalizedIndiaMobile(raw)
                guard phone.count == RupeeFieldLimit.mobileSubmit, !seenPhones.contains(phone) else { continue }

                seenPhones.insert(phone)
                rows.append([
                    "contactName": name,
                    "contactPhone": phone,
                    "contactUpdateTime": revisedMs,
                    "contactStorage": "1",
                    "contactCount": "-99",
                    "contactTime": ""
                ])
                if rows.count >= cap { return rows }
            }
        }

        return rows.isEmpty ? [Self.placeholderRow] : rows
    }

    private static func displayName(from person: ABRecord) -> String {
        let family = stringValue(person, kABPersonLastNameProperty)
        let given = stringValue(person, kABPersonFirstNameProperty)
        let composed = [family, given].filter { !$0.isEmpty }.joined(separator: " ")
        if !composed.isEmpty { return composed }
        return stringValue(person, kABPersonOrganizationProperty)
    }

    private static func modificationMillis(from person: ABRecord) -> String {
        guard let date = ABRecordCopyValue(person, kABPersonModificationDateProperty)?.takeRetainedValue() as? Date else {
            return "0"
        }
        return String(Int64(date.timeIntervalSince1970 * 1000))
    }

    private static func phoneNumbers(from person: ABRecord) -> [String] {
        guard let values = ABRecordCopyValue(person, kABPersonPhoneProperty)?.takeRetainedValue() else {
            return []
        }
        let multi = values as ABMultiValue
        var phones: [String] = []
        for index in 0..<ABMultiValueGetCount(multi) {
            guard let raw = ABMultiValueCopyValueAtIndex(multi, index)?.takeRetainedValue() as? String else {
                continue
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { phones.append(trimmed) }
        }
        return phones
    }

    private static func stringValue(_ person: ABRecord, _ property: ABPropertyID) -> String {
        (ABRecordCopyValue(person, property)?.takeRetainedValue() as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
