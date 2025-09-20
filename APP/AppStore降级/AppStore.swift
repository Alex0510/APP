//
//  AppStore.swift
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import SwiftUI
import Combine

/// 应用商店管理类，负责多账户管理和全局配置
@MainActor
class AppStore: ObservableObject {
    /// 单例实例
    static let shared = AppStore()
    
    /// 所有登录的账户
    @Published var accounts: [Account] = []
    
    /// 当前选中的账户
    @Published var selectedAccount: Account? = nil
    
    private let accountsKey = "SavedAccounts"
    
    /// 初始化，确保单例模式
    private init() {
        loadAccounts()
    }
    
    /// 加载所有账户数据
    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let savedAccounts = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = savedAccounts
            selectedAccount = accounts.first
            // 设置当前账户的Cookie
            setCurrentAccountCookies()
            print("[AppStore] 加载了 \(accounts.count) 个账户")
        }
    }
    
    /// 保存所有账户数据
    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
            print("[AppStore] 保存了 \(accounts.count) 个账户")
        }
    }
    
    /// 登录账户 - 使用 AuthenticationManager 进行认证（添加到账户列表）
    func loginAccount(email: String, password: String, code: String?) async throws {
        // 调用认证方法
        let account = try await AuthenticationManager.shared.authenticate(
            email: email,
            password: password,
            mfa: code
        )
        
        // 检查是否已经存在该账户
        if let existingIndex = accounts.firstIndex(where: { $0.email == account.email }) {
            // 更新现有账户
            accounts[existingIndex] = account
            print("[AppStore] 更新账户: \(account.email), 地区: \(account.countryCode)")
        } else {
            // 添加新账户
            accounts.append(account)
            print("[AppStore] 添加账户: \(account.email), 地区: \(account.countryCode)")
        }
        
        // 设置当前选中账户
        selectedAccount = account
        
        // 保存账户列表
        saveAccounts()
        
        // 设置当前账户的Cookie
        setCurrentAccountCookies()
        
        // 发送通知更新UI
        NotificationCenter.default.post(name: NSNotification.Name("AccountLoggedIn"), object: nil)
    }
    
    /// 删除账户
    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.email == account.email }
        
        // 如果删除的是当前选中账户，则选择另一个账户
        if selectedAccount?.email == account.email {
            selectedAccount = accounts.first
        }
        
        // 保存账户列表
        saveAccounts()
        
        print("[AppStore] 删除账户: \(account.email)")
    }
    
    /// 切换当前选中的账户
    func switchAccount(to account: Account) {
        selectedAccount = account
        // 设置当前账户的Cookie
        setCurrentAccountCookies()
        print("[AppStore] 切换到账户: \(account.email)")
    }
    
    /// 刷新账户令牌
    func refreshAccountTokens(for account: Account) async throws {
        print("[AppStore] 刷新账户令牌: \(account.email)")
        
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        
        // 调用AuthenticationManager验证账户
        if await AuthenticationManager.shared.validateAccount(account) {
            // 刷新cookie
            let updatedAccount = AuthenticationManager.shared.refreshCookies(for: account)
            
            // 更新账户信息
            if let index = accounts.firstIndex(where: { $0.email == updatedAccount.email }) {
                accounts[index] = updatedAccount
                if selectedAccount?.email == updatedAccount.email {
                    selectedAccount = updatedAccount
                }
                saveAccounts()
                print("[AppStore] 账户令牌已刷新: \(updatedAccount.email)")
            }
        } else {
            print("[AppStore] 账户验证失败，需要重新登录")
            // 可以选择删除无效账户或提示用户重新登录
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
    
    /// 登出当前账户
    func logoutAccount() {
        if let account = selectedAccount {
            deleteAccount(account)
        }
    }
    
    /// 获取当前选中账户的地区代码
    var currentAccountRegion: String {
        return selectedAccount?.countryCode ?? "US"
    }
    
    /// 获取当前选中账户的storeFront
    var currentAccountStoreFront: String {
        return selectedAccount?.storeFront ?? "143441-1,29"
    }
}
