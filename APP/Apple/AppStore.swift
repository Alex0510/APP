//
//  AppStore.swift
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import SwiftUI
import Combine
/// 应用商店管理类，负责账户管理和全局配置
@MainActor
class AppStore: ObservableObject {
    /// 单例实例
    static let this = AppStore()
    /// 账户列表
    @Published var accounts: [Account] = []
    /// 当前选中的账户
    @Published var selectedAccount: Account? = nil
    /// 初始化，确保单例模式
    private init() {
        loadAccounts()
        // 自动选择第一个账户作为当前账户
        if !accounts.isEmpty {
            selectedAccount = accounts.first
        }
    }
    /// 设置GUID
    func setupGUID() {
        // 设置应用的唯一标识符
        // 这里可以实现GUID的设置逻辑
    }
    /// 加载账户数据
    private func loadAccounts() {
        // 从 AuthenticationManager 加载保存的账户
        if let savedAccount = AuthenticationManager.shared.loadSavedAccount() {
            accounts = [savedAccount]
            // 自动选择第一个账户作为当前账户
            selectedAccount = savedAccount
            print("[AppStore] 加载账户: \(savedAccount.email), 地区: \(savedAccount.countryCode)")
        } else {
            print("[AppStore] 没有找到保存的账户")
            accounts = []
            selectedAccount = nil
        }
    }
    /// 添加账户 - 使用 AuthenticationManager 进行认证
    func addAccount(email: String, password: String, code: String?) async throws {
        // 直接调用authenticate方法，它会抛出错误或返回成功的账户
        let account = try await AuthenticationManager.shared.authenticate(
            email: email,
            password: password,
            mfa: code
        )
        // 保存认证成功的账户
        try AuthenticationManager.shared.saveAccount(account)
        accounts.append(account)
        
        // 自动选择新添加的账户作为当前账户
        selectedAccount = account
        print("[AppStore] 新账户添加成功: \(account.email), 地区: \(account.countryCode)")
        
        saveAccounts()
    }
    /// 删除账户
    func delete(id: Account.ID) {
        accounts.removeAll { $0.id == id }
        // 如果删除的是当前保存的账户，也从Keychain中删除
        if let savedAccount = AuthenticationManager.shared.loadSavedAccount(),
           savedAccount.id == id {
            _ = AuthenticationManager.shared.deleteSavedAccount()
        }
        saveAccounts()
    }
    /// 刷新账户状态
    func refreshAccounts() {
        // 重新加载账户数据
        loadAccounts()
        objectWillChange.send()
    }
    /// 保存账户信息
    func save(account: Account) {
        // 更新现有账户或添加新账户
        if let index = accounts.firstIndex(where: { $0.email == account.email }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        // 通过 AuthenticationManager 保存到 Keychain
        try? AuthenticationManager.shared.saveAccount(account)
        saveAccounts()
    }
    /// 轮换账户令牌
    func rotate(id: Account.ID) async throws -> Account {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw StoreError.accountNotFound
        }
        let account = accounts[index]
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        // 调用AuthenticationManager验证账户
        if await AuthenticationManager.shared.validateAccount(account) {
            // 刷新cookie
            let updatedAccount = AuthenticationManager.shared.refreshCookies(for: account)
            // 更新账户信息
            accounts[index] = updatedAccount
            saveAccounts()
            return updatedAccount
        } else {
            throw StoreError.authenticationFailed
        }
    }
    /// 保存账户数据
    private func saveAccounts() {
        // 实现账户数据的持久化存储
        // 应该使用Keychain等安全存储
    }
    
    /// 切换当前选中的账户
    func selectAccount(_ account: Account) {
        selectedAccount = account
        print("[AppStore] 切换到账户: \(account.email), 地区: \(account.countryCode)")
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        objectWillChange.send()
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
