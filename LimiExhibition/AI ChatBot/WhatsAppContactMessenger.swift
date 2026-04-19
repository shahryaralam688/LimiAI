//
//  WhatsAppContactMessenger.swift
//  LimiExhibition
//
//  Resolves a contact (or explicit phone) and opens WhatsApp with a pre-filled draft via wa.me.
//  The user must tap Send in WhatsApp; there is no silent send API for consumer apps.
//

import Contacts
import Foundation
import UIKit

enum WhatsAppContactMessengerError: LocalizedError {
    case contactsDenied
    case missingRecipient
    case emptyMessage
    case contactNotFound(String)
    case noPhoneNumber(String)
    case phoneTooShort
    case couldNotBuildURL
    case openFailed

    var errorDescription: String? {
        switch self {
        case .contactsDenied:
            return "Contacts access is denied. Enable it in Settings to find people by name."
        case .missingRecipient:
            return "Need a contact name or phone number for WhatsApp."
        case .emptyMessage:
            return "Message text is empty."
        case .contactNotFound(let name):
            return "No contact matched “\(name)”."
        case .noPhoneNumber(let name):
            return "No usable phone number for \(name)."
        case .phoneTooShort:
            return "Phone number is too short. Include country code in Contacts or pass a full number."
        case .couldNotBuildURL:
            return "Could not build WhatsApp link."
        case .openFailed:
            return "Could not open WhatsApp."
        }
    }
}

final class WhatsAppContactMessenger {
    static let shared = WhatsAppContactMessenger()

    private let store = CNContactStore()

    private init() {}

    /// Opens WhatsApp with a draft. Supply either `contactName` (address book) or `phoneDigitsOverride` (digits / + allowed).
    func openDraft(contactName: String?, phoneDigitsOverride: String?, message: String, completion: @escaping (Result<String, Error>) -> Void) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            completion(.failure(WhatsAppContactMessengerError.emptyMessage))
            return
        }

        let trimmedPhone = phoneDigitsOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = contactName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let p = trimmedPhone, !p.isEmpty {
            let digits = Self.normalizeDigits(p)
            guard digits.count >= 8 else {
                completion(.failure(WhatsAppContactMessengerError.phoneTooShort))
                return
            }
            openWhatsAppOnMain(digits: digits, message: trimmedMessage, label: digits, completion: completion)
            return
        }

        guard let name = trimmedName, !name.isEmpty else {
            completion(.failure(WhatsAppContactMessengerError.missingRecipient))
            return
        }

        requestAccessIfNeeded { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let digits = try self.findBestPhoneDigits(forContactName: name)
                        let label = self.displayNameForLastLookup ?? name
                        DispatchQueue.main.async {
                            self.openWhatsAppOnMain(digits: digits, message: trimmedMessage, label: label, completion: completion)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    private var displayNameForLastLookup: String?

    private func requestAccessIfNeeded(completion: @escaping (Result<Void, Error>) -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            completion(.success(()))
        case .denied, .restricted:
            completion(.failure(WhatsAppContactMessengerError.contactsDenied))
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    completion(.failure(error))
                } else if granted {
                    completion(.success(()))
                } else {
                    completion(.failure(WhatsAppContactMessengerError.contactsDenied))
                }
            }
        @unknown default:
            completion(.failure(WhatsAppContactMessengerError.contactsDenied))
        }
    }

    private func findBestPhoneDigits(forContactName name: String) throws -> String {
        displayNameForLastLookup = nil
        let tokens = Self.nameTokens(from: name)
        guard !tokens.isEmpty else {
            throw WhatsAppContactMessengerError.contactNotFound(name)
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var candidates: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            if Self.matchScore(contact: contact, tokens: tokens) == tokens.count {
                candidates.append(contact)
            }
        }
        guard let contact = Self.pickBestContact(from: candidates, tokens: tokens) else {
            throw WhatsAppContactMessengerError.contactNotFound(name)
        }
        displayNameForLastLookup = Self.formatContactName(contact)
        guard let labeled = contact.phoneNumbers.first else {
            throw WhatsAppContactMessengerError.noPhoneNumber(Self.formatContactName(contact))
        }
        let digits = Self.normalizeDigits(labeled.value.stringValue)
        guard digits.count >= 8 else {
            throw WhatsAppContactMessengerError.noPhoneNumber(Self.formatContactName(contact))
        }
        return digits
    }

    private func openWhatsAppOnMain(digits: String, message: String, label: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = Self.waMeURL(phoneDigits: digits, message: message) else {
            completion(.failure(WhatsAppContactMessengerError.couldNotBuildURL))
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                completion(.success("Opened WhatsApp for \(label). Ask the user to tap Send."))
            } else {
                completion(.failure(WhatsAppContactMessengerError.openFailed))
            }
        }
    }

    private static func nameTokens(from name: String) -> [String] {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func matchScore(contact: CNContact, tokens: [String]) -> Int {
        let full = "\(contact.givenName) \(contact.familyName) \(contact.nickname)"
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        var matched = 0
        for t in tokens where full.contains(t) {
            matched += 1
        }
        return matched
    }

    private static func pickBestContact(from contacts: [CNContact], tokens: [String]) -> CNContact? {
        guard !contacts.isEmpty else { return nil }
        if contacts.count == 1 { return contacts[0] }
        let first = tokens.first?.lowercased() ?? ""
        return contacts.sorted { a, b in
            let aGiven = a.givenName.lowercased() == first
            let bGiven = b.givenName.lowercased() == first
            if aGiven != bGiven { return aGiven && !bGiven }
            return a.phoneNumbers.count > b.phoneNumbers.count
        }.first
    }

    private static func formatContactName(_ c: CNContact) -> String {
        let parts = [c.givenName, c.familyName].filter { !$0.isEmpty }
        if parts.isEmpty, !c.nickname.isEmpty { return c.nickname }
        return parts.joined(separator: " ")
    }

    static func normalizeDigits(_ raw: String) -> String {
        raw.filter(\.isNumber)
    }

    static func waMeURL(phoneDigits: String, message: String) -> URL? {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(phoneDigits)?text=\(encoded)")
    }
}
