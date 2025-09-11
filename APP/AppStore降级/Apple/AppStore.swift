//
//  AppStore.swift
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import SwiftUI
import Combine
/// 应用商店管理类，负责单一账户管理和全局配置
@MainActor
class AppStore: ObservableObject {
    /// 单例实例
    static let this = AppStore()
    /// 当前唯一登录的账户（确保只有一个Apple ID）
    @Published var selectedAccount: Account? = nil
    /// 初始化，确保单例模式
    private init() {
        loadAccount()
    }
    /// 设置GUID
    func setupGUID() {
        // 设置应用的唯一标识符
        // 这里可以实现GUID的设置逻辑
    }
    /// 加载唯一账户数据
    private func loadAccount() {
        // 从 AuthenticationManager 加载保存的账户
        if let savedAccount = AuthenticationManager.shared.loadSavedAccount() {
            selectedAccount = savedAccount
            print("[AppStore] 加载账户: \(savedAccount.email), 地区: \(savedAccount.countryCode)")
        } else {
            print("[AppStore] 没有找到保存的账户")
            selectedAccount = nil
        }
    }
    /// 登录账户 - 使用 AuthenticationManager 进行认证（替换现有账户）
    func loginAccount(email: String, password: String, code: String?) async throws {
        // 如果已有账户，先登出
        if selectedAccount != nil {
            logoutAccount()
        }
        
        // 直接调用authenticate方法，它会抛出错误或返回成功的账户
        let account = try await AuthenticationManager.shared.authenticate(
            email: email,
            password: password,
            mfa: code
        )
        // 保存认证成功的账户
        try AuthenticationManager.shared.saveAccount(account)
        
        // 设置为当前唯一账户
        selectedAccount = account
        print("[AppStore] 账户登录成功: \(account.email), 地区: \(account.countryCode)")
    }
    /// 登出当前账户
    func logoutAccount() {
        // 从Keychain中删除账户
        _ = AuthenticationManager.shared.deleteSavedAccount()
        // 清除当前账户
        selectedAccount = nil
        print("[AppStore] 账户已登出")
    }
    /// 刷新账户状态
    func refreshAccount() {
        // 重新加载账户数据
        loadAccount()
        objectWillChange.send()
    }
    /// 更新当前账户信息
    func updateAccount(_ account: Account) {
        // 更新当前账户
        selectedAccount = account
        // 通过 AuthenticationManager 保存到 Keychain
        try? AuthenticationManager.shared.saveAccount(account)
        print("[AppStore] 账户信息已更新: \(account.email)")
    }
    /// 刷新当前账户令牌
    func refreshCurrentAccount() async throws {
        guard let account = selectedAccount else {
            print("[AppStore] 没有当前账户需要刷新")
            return
        }
        
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        // 调用AuthenticationManager验证账户
        if await AuthenticationManager.shared.validateAccount(account) {
            // 刷新cookie
            let updatedAccount = AuthenticationManager.shared.refreshCookies(for: account)
            // 更新当前账户信息
            selectedAccount = updatedAccount
            print("[AppStore] 账户令牌已刷新: \(updatedAccount.email)")
        } else {
            print("[AppStore] 账户验证失败，需要重新登录")
            logoutAccount()
        }
    }

    
    /// 设置当前账户的Cookie
    func setCurrentAccountCookies() {
        guard let account = selectedAccount else {
            print("[AppStore] 没有当前账户可设置Cookie")
            return
        }
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        print("[AppStore] 已设置账户Cookie: \(account.email)")
    }
    
    /// 获取当前选中账户的地区代码
    var currentAccountRegion: String {
        return selectedAccount?.countryCode ?? "US"
    }
}
// MARK: - Account 模型
extension AppStore {
    // Account struct moved to AuthenticationManager.swift to avoid duplication
}
