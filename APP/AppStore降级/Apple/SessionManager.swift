//
//  SessionManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation
import Combine
import SwiftUI

/// Apple ID会话管理器 - 处理掉线检测和自动重连
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isSessionValid = true
    @Published var isReconnecting = false
    @Published var lastSessionCheck = Date()
    @Published var sessionError: String?
    
    private var sessionTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private let sessionCheckInterval: TimeInterval = 30 // 30秒检查一次
    private let sessionTimeout: TimeInterval = 300 // 5分钟超时
    
    private init() {
        startSessionMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            stopSessionMonitoring()
        }
    }
    
    // MARK: - 会话监控
    
    /// 开始会话监控
    func startSessionMonitoring() {
        print("🔐 [SessionManager] 开始会话监控")
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSessionValidity()
            }
        }
    }
    
    /// 停止会话监控
    func stopSessionMonitoring() {
        print("🔐 [SessionManager] 停止会话监控")
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    /// 检查会话有效性
    func checkSessionValidity() async {
        guard let account = AuthenticationManager.shared.loadSavedAccount() else {
            print("🔐 [SessionManager] 没有保存的账户，跳过会话检查")
            return
        }
        
        print("🔐 [SessionManager] 检查会话有效性...")
        
        do {
            // 尝试一个轻量级的API调用来验证会话
            let isValid = await validateSessionWithAPI(account: account)
            
            if isValid {
                print("✅ [SessionManager] 会话有效")
                isSessionValid = true
                sessionError = nil
                reconnectAttempts = 0
                lastSessionCheck = Date()
            } else {
                print("❌ [SessionManager] 会话无效，需要重新认证")
                await handleSessionInvalid()
            }
        } catch {
            print("❌ [SessionManager] 会话检查失败: \(error)")
            await handleSessionInvalid()
        }
    }
    
    /// 使用API验证会话
    private func validateSessionWithAPI(account: Account) async -> Bool {
        // 使用AuthenticationManager验证会话
        return await AuthenticationManager.shared.validateAccount(account)
    }
    
    /// 处理会话无效
    private func handleSessionInvalid() async {
        print("🔐 [SessionManager] 处理会话无效")
        isSessionValid = false
        
        if reconnectAttempts < maxReconnectAttempts {
            await attemptReconnection()
        } else {
            sessionError = "Apple ID会话已过期，请重新登录"
            print("🔐 [SessionManager] 重连尝试次数已达上限")
        }
    }
    
    /// 尝试重新连接
    private func attemptReconnection() async {
        guard let account = AuthenticationManager.shared.loadSavedAccount() else {
            print("🔐 [SessionManager] 没有保存的账户，无法重连")
            return
        }
        
        reconnectAttempts += 1
        isReconnecting = true
        sessionError = "正在重新连接... (\(reconnectAttempts)/\(maxReconnectAttempts))"
        
        print("🔄 [SessionManager] 尝试重新连接 (\(reconnectAttempts)/\(maxReconnectAttempts))")
        
        // 尝试刷新Cookie
        let refreshedAccount = AuthenticationManager.shared.refreshCookies(for: account)
        
        // 验证重连是否成功
        let isValid = await validateSessionWithAPI(account: refreshedAccount)
        
        if isValid {
            print("✅ [SessionManager] 重连成功")
            isSessionValid = true
            isReconnecting = false
            sessionError = nil
            reconnectAttempts = 0
            lastSessionCheck = Date()
            
            // 通知下载管理器会话已恢复
            await notifySessionRestored()
        } else {
            print("❌ [SessionManager] 重连失败")
            isReconnecting = false
            sessionError = "重连失败，请检查网络连接"
        }
    }
    
    /// 通知会话已恢复
    private func notifySessionRestored() async {
        print("🔐 [SessionManager] 通知会话已恢复")
        
        // 通知下载管理器
        NotificationCenter.default.post(name: .sessionRestored, object: nil)
        
        // 通知AppStore
        if let appStore = AppStore.this as? AppStore {
            appStore.refreshAccount()
        }
    }
    
    // MARK: - 手动操作
    
    /// 手动检查会话
    func manualSessionCheck() async {
        print("🔐 [SessionManager] 手动检查会话")
        await checkSessionValidity()
    }
    
    /// 强制重新认证
    func forceReauthentication() async {
        print("🔐 [SessionManager] 强制重新认证")
        isSessionValid = false
        isReconnecting = false
        sessionError = "需要重新登录"
        reconnectAttempts = maxReconnectAttempts
    }
    
    /// 重置会话状态
    func resetSessionState() {
        print("🔐 [SessionManager] 重置会话状态")
        isSessionValid = true
        isReconnecting = false
        sessionError = nil
        reconnectAttempts = 0
        lastSessionCheck = Date()
    }
    
    // MARK: - 下载任务恢复
    
    /// 恢复因会话失效而暂停的下载任务
    func resumeFailedDownloads() async {
        print("🔐 [SessionManager] 恢复失败的下载任务")
        
        let downloadManager = UnifiedDownloadManager.shared
        
        for request in downloadManager.downloadRequests {
            if request.runtime.status == .failed && 
               request.runtime.error?.contains("认证") == true {
                print("🔄 [SessionManager] 恢复下载任务: \(request.name)")
                
                // 重置任务状态
                request.runtime.status = .waiting
                request.runtime.error = nil
                request.runtime.progressValue = 0
                
                // 重新开始下载
                downloadManager.startDownload(for: request)
            }
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let sessionRestored = Notification.Name("sessionRestored")
    static let sessionInvalid = Notification.Name("sessionInvalid")
}

// MARK: - 下载管理器扩展
extension UnifiedDownloadManager {
    
    /// 监听会话状态变化
    func setupSessionMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .sessionRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSessionRestored()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .sessionInvalid,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSessionInvalid()
            }
        }
    }
    
    /// 处理会话恢复
    private func handleSessionRestored() async {
        print("🔄 [UnifiedDownloadManager] 处理会话恢复")
        
        // 恢复失败的下载任务
        for request in downloadRequests {
            if request.runtime.status == .failed {
                print("🔄 [UnifiedDownloadManager] 恢复下载任务: \(request.name)")
                request.runtime.status = .waiting
                request.runtime.error = nil
                startDownload(for: request)
            }
        }
    }
    
    /// 处理会话失效
    private func handleSessionInvalid() async {
        print("⏸️ [UnifiedDownloadManager] 处理会话失效")
        
        // 暂停所有下载任务
        for request in downloadRequests {
            if request.runtime.status == .downloading {
                print("⏸️ [UnifiedDownloadManager] 暂停下载任务: \(request.name)")
                request.runtime.status = .failed
                request.runtime.error = "Apple ID会话已过期，正在重新连接..."
            }
        }
    }
}

