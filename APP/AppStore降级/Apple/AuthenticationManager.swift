//
//  AuthenticationManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import Security
/// 用于处理用户凭证和会话管理的认证管理器
class AuthenticationManager {
    static let shared = AuthenticationManager()
    private let keychainService = "ipatool.swift.service"
    private let keychainAccount = "account"
    private let storeRequest = StoreRequest.shared
    private init() {}
    /// 使用Apple ID认证用户
    /// - 参数:
    ///   - email: Apple ID邮箱
    ///   - password: Apple ID密码
    ///   - mfa: 双因素认证代码(可选)
    /// - 返回: 账户信息
    func authenticate(email: String, password: String, mfa: String? = nil) async throws -> Account {
        let response = try await StoreRequest.shared.authenticate(
            email: email,
            password: password,
            mfa: mfa
        )
        // 获取Cookie
        let cookieStrings = getCurrentCookies()
        // 准备账户信息
        let firstName = response.accountInfo.address.firstName
        let lastName = response.accountInfo.address.lastName
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? email : name
        // 使用完整的Account初始化器，确保提供所有必需的参数
        let account = Account(
            name: finalName,
            email: email,
            firstName: firstName,
            lastName: lastName,
            passwordToken: response.passwordToken,
            directoryServicesIdentifier: response.dsPersonId,
            dsPersonId: response.dsPersonId,
            cookies: cookieStrings,
            countryCode: response.accountInfo.countryCode ?? "US",
            storeResponse: Account.StoreResponse(
                directoryServicesIdentifier: response.dsPersonId,
                passwordToken: response.passwordToken,
                storeFront: response.accountInfo.storeFront ?? "143441-1,29"
            )
        )
        // 保存到钥匙串
        do {
            try saveAccountToKeychain(account)
        } catch {
            print("警告: 无法将账户保存到钥匙串: \(error)")
        }
        return account
    }
    /// 从钥匙串加载账户
    /// - 返回: 如果存在则返回已保存的账户
    func loadSavedAccount() -> Account? {
        return loadAccountFromKeychain()
    }
    /// 将账户保存到钥匙串
    /// - 参数 account: 要保存的账户
    /// - 抛出: 如果保存失败则抛出错误
    func saveAccount(_ account: Account) throws {
        try saveAccountToKeychain(account)
    }
    /// 从钥匙串删除已保存的账户
    /// - 返回: 如果删除成功则返回true
    func deleteSavedAccount() -> Bool {
        return deleteAccountFromKeychain()
    }
    /// 验证账户凭证是否仍然有效
    /// - 参数 account: 要验证的账户
    /// - 返回: 如果账户仍然有效则返回true
    func validateAccount(_ account: Account) async -> Bool {
        // 尝试发起一个简单的请求来验证账户
        // 可以通过发起一个轻量级的API调用来实现
        return true // 占位实现
    }
    /// 刷新账户的Cookie
    /// - 参数 account: 要刷新Cookie的账户
    /// - 返回: 带有新Cookie的更新后的账户
    func refreshCookies(for account: Account) -> Account {
        let updatedAccount = Account(
            name: account.name,
            email: account.email,
            firstName: account.firstName,
            lastName: account.lastName,
            passwordToken: account.passwordToken,
            directoryServicesIdentifier: account.directoryServicesIdentifier,
            dsPersonId: account.dsPersonId,
            cookies: getCurrentCookies(),
            countryCode: account.countryCode,
            storeResponse: account.storeResponse
        )
        // 保存更新后的账户
        do {
            try saveAccountToKeychain(updatedAccount)
        } catch {
            print("警告: 无法保存更新后的账户: \(error)")
        }
        return updatedAccount
    }
    // MARK: - Cookie管理
    /// 获取当前的Cookie
    private func getCurrentCookies() -> [String] {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return [] }
        return cookies.compactMap { cookie in
            if cookie.domain.contains("apple.com") || cookie.domain.contains("itunes.apple.com") {
                return cookie.description
            }
            return nil
        }
    }
    /// 在HTTPCookieStorage中设置Cookie
    /// - 参数 cookieStrings: 要设置的Cookie字符串数组
    func setCookies(_ cookies: [String]) {
        for cookieString in cookies {
            let components = cookieString.components(separatedBy: ";")
            var cookieDict: [HTTPCookiePropertyKey: Any] = [:]
            for component in components {
                let parts = component.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    if parts[0].lowercased() == "domain" {
                        cookieDict[.domain] = parts[1]
                    } else if parts[0].lowercased() == "path" {
                        cookieDict[.path] = parts[1]
                    } else if parts[0].lowercased() == "secure" {
                        cookieDict[.secure] = true
                    } else {
                        cookieDict[.name] = parts[0]
                        cookieDict[.value] = parts[1]
                    }
                }
            }
            if let _ = cookieDict[.name] as? String, let _ = cookieDict[.value] as? String {
                cookieDict[.domain] = cookieDict[.domain] as? String ?? ".apple.com"
                cookieDict[.path] = cookieDict[.path] as? String ?? "/"
                if let cookie = HTTPCookie(properties: cookieDict) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }
    func clearCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies {
            if cookie.domain.contains("apple.com") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    // MARK: - 钥匙串管理
    /// 将账户保存到钥匙串
    private func saveAccountToKeychain(_ account: Account) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecValueData as String: data
        ]
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychainError
        }
    }
    /// 从钥匙串加载账户
    private func loadAccountFromKeychain() -> Account? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Account.self, from: data)
    }
    /// 从钥匙串删除账户
    private func deleteAccountFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
// MARK: - 账户模型
// 账户定义现在位于Apple.swift中，以避免重复
