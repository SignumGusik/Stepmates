//
//  AccessTokenStorage.swift
//  Stepmates Auth
//
//  Created by Диана on 27/01/2026.
//

import Foundation
import Security

struct AccessTokenStorage {
    
    private let accountkey = "com.signumina"
    
    @discardableResult
    func save(_ token: AccessToken) -> Bool {
        _ = delete()
        guard let data = try? JSONEncoder().encode(token) else {
            return false
        }
        
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: accountkey, kSecValueData: data]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func get() -> AccessToken? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: accountkey, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(AccessToken.self, from: data)
    }
    @discardableResult
    func delete() -> Bool {
        let deleteQuery: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: accountkey]
        
        var status = SecItemDelete(deleteQuery as CFDictionary)
        return status == errSecSuccess
    }
    
}
