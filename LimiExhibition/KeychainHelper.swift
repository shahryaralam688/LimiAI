////
////  KeychainHelper.swift
////  Limi
////
////  Created by Shahrukh Ahmed on 16/12/2025.
////
//
//import Foundation
//import Security
//
//final class KeychainHelper {
//
//    static let shared = KeychainHelper()
//    private init() {}
//
//    func save(_ value: String, for key: String) {
//        let data = Data(value.utf8)
//
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrAccount as String: key,
//            kSecValueData as String: data,
//            kSecAttrAccessible as String:
//                kSecAttrAccessibleAfterFirstUnlock
//        ]
//
//        SecItemDelete(query as CFDictionary)
//        SecItemAdd(query as CFDictionary, nil)
//    }
//
//    func read(_ key: String) -> String? {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrAccount as String: key,
//            kSecReturnData as String: true,
//            kSecMatchLimit as String: kSecMatchLimitOne
//        ]
//
//        var result: AnyObject?
//        let status = SecItemCopyMatching(
//            query as CFDictionary,
//            &result
//        )
//
//        guard status == errSecSuccess,
//              let data = result as? Data else {
//            return nil
//        }
//
//        return String(decoding: data, as: UTF8.self)
//    }
//
//    func delete(_ key: String) {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrAccount as String: key
//        ]
//
//        SecItemDelete(query as CFDictionary)
//    }
//}
