//
//  UnifiedDownloadManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//

import Foundation
import SwiftUI
import Combine


// DownloadManager.swift 包含 DownloadStatus 等类型定义
// AppStore.swift 包含 AppStore 类定义
// AuthenticationManager.swift 包含 AuthenticationManager 和 Account 类型

/// 底层下载和UI层管理
@MainActor
class UnifiedDownloadManager: ObservableObject {
    static let shared = UnifiedDownloadManager()
    
    @Published var downloadRequests: [DownloadRequest] = []
    @Published var completedRequests: Set<UUID> = []
    @Published var activeDownloads: Set<UUID> = []
    
    private let downloadManager = AppStoreDownloadManager.shared
    private let purchaseManager = PurchaseManager.shared
    
    private init() {
        setupSessionMonitoring()
    }
    
    /// 添加下载请求
    func addDownload(
        bundleIdentifier: String,
        name: String,
        version: String,
        identifier: Int,
        iconURL: String? = nil,
        versionId: String? = nil
    ) -> UUID {
        print("🔍 [添加下载] 开始添加下载请求")
        print("   - Bundle ID: \(bundleIdentifier)")
        print("   - 名称: \(name)")
        print("   - 版本: \(version)")
        print("   - 标识符: \(identifier)")
        print("   - 版本ID: \(versionId ?? "无")")
        
        let package = DownloadArchive(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: version,
            identifier: identifier,
            iconURL: iconURL
        )
        
        let request = DownloadRequest(
            bundleIdentifier: bundleIdentifier,
            version: version,
            name: name,
            package: package,
            versionId: versionId
        )
        
        downloadRequests.append(request)
        print("✅ [添加下载] 下载请求已添加，ID: \(request.id)")
        print("📊 [添加下载] 当前下载请求总数: \(downloadRequests.count)")
        print("🖼️ [图标信息] 图标URL: \(request.iconURL ?? "无")")
        print("📦 [包信息] 包名称: \(request.package.name), 标识符: \(request.package.identifier)")
        return request.id
    }
    
    /// 删除下载请求
    func deleteDownload(request: DownloadRequest) {
        if let index = downloadRequests.firstIndex(where: { $0.id == request.id }) {
            downloadRequests.remove(at: index)
            activeDownloads.remove(request.id)
            completedRequests.remove(request.id)
            print("🗑️ [删除下载] 已删除下载请求: \(request.name)")
        }
    }
    
    /// 开始下载
    func startDownload(for request: DownloadRequest) {
        guard !activeDownloads.contains(request.id) else { 
            print("⚠️ [下载跳过] 请求 \(request.id) 已在下载队列中")
            return 
        }
        
        print("🚀 [下载启动] 开始下载: \(request.name) v\(request.version)")
        print("🔍 [调试] 下载请求详情:")
        print("   - Bundle ID: \(request.bundleIdentifier)")
        print("   - 版本: \(request.version)")
        print("   - 版本ID: \(request.versionId ?? "无")")
        print("   - 包标识符: \(request.package.identifier)")
        print("   - 包名称: \(request.package.name)")
        print("   - 当前状态: \(request.runtime.status)")
        print("   - 当前进度: \(request.runtime.progressValue)")
        
        activeDownloads.insert(request.id)
        request.runtime.status = .downloading
        request.runtime.error = nil
        
        // 重置进度，使用动态大小
        request.runtime.progress = Progress(totalUnitCount: 0)
        request.runtime.progress.completedUnitCount = 0
        
        print("✅ [状态更新] 状态已设置为: \(request.runtime.status)")
        print("✅ [进度重置] 进度已重置为: \(request.runtime.progressValue)")
        
        Task {
            guard let account = AppStore.shared.selectedAccount else {
                await MainActor.run {
                    request.runtime.error = "请先添加Apple ID账户"
                    request.runtime.status = .failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [认证失败] 未找到有效的Apple ID账户")
                }
                return
            }
            
            print("🔐 [认证信息] 使用账户: \(account.email)")
            print("🏪 [商店信息] StoreFront: \(account.storeResponse.storeFront)")
            
            // 确保认证状态
            AuthenticationManager.shared.setCookies(account.cookies)
            
            // 借鉴旧代码的成功实现 - 使用正确的Account结构体
            let storeAccount = Account(
                name: account.email,
                email: account.email,
                firstName: account.firstName,
                lastName: account.lastName,
                passwordToken: account.storeResponse.passwordToken,
                directoryServicesIdentifier: account.storeResponse.directoryServicesIdentifier,
                dsPersonId: account.storeResponse.directoryServicesIdentifier,
                cookies: account.cookies,
                countryCode: account.countryCode,
                storeResponse: account.storeResponse
            )
            
            // 检查会话有效性
            let isValid = await AuthenticationManager.shared.validateAccount(storeAccount)
            if !isValid {
                await MainActor.run {
                    request.runtime.error = "Apple ID会话已过期，请重新登录"
                    request.runtime.status = .failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [会话失效] Apple ID会话已过期")
                }
                return
            }
            
            // 验证地区设置（简单验证，避免状态变化）
            let regionValidation = (account.countryCode == storeAccount.countryCode)
            
            if !regionValidation {
                await MainActor.run {
                    request.runtime.error = "地区设置不匹配，请检查账户地区设置"
                    request.runtime.status = .failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [地区错误] 账户地区与设置不匹配")
                }
                return
            }
            
            // 增加购买验证流程
            print("🔍 [购买验证] 开始验证应用所有权: \(request.name)")
            let purchaseResult = await purchaseManager.purchaseAppIfNeeded(
                appIdentifier: String(request.package.identifier),
                account: storeAccount,
                countryCode: account.countryCode
            )
            
            switch purchaseResult {
            case .success(let result):
                print("✅ [购买验证] \(result.message)")
                // 购买验证成功，继续下载
                proceedWithDownload(
                    for: request,
                    storeAccount: storeAccount
                )
            case .failure(let error):
                await MainActor.run {
                    request.runtime.error = error.localizedDescription
                    request.runtime.status = .failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [购买失败] \(request.name): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 购买验证成功后继续下载
    private func proceedWithDownload(
        for request: DownloadRequest,
        storeAccount: Account
    ) {
        // 创建目标文件URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sanitizedName = request.package.name.replacingOccurrences(of: "/", with: "_")
        let destinationURL = documentsPath.appendingPathComponent("\(sanitizedName)_\(request.version).ipa")
        
        print("📁 [文件路径] 目标位置: \(destinationURL.path)")
        print("🆔 [应用信息] ID: \(request.package.identifier), 版本: \(request.versionId ?? request.version)")
        
        // 使用DownloadManager进行下载
        downloadManager.downloadApp(
            appIdentifier: String(request.package.identifier),
            account: storeAccount,
            destinationURL: destinationURL,
            appVersion: request.versionId,
            progressHandler: { downloadProgress in
                Task { @MainActor in
                    // 使用新的进度更新方法
                    request.runtime.updateProgress(
                        completed: downloadProgress.bytesDownloaded,
                        total: downloadProgress.totalBytes
                    )
                    request.runtime.speed = downloadProgress.formattedSpeed
                    request.runtime.status = downloadProgress.status
                    
                    // 每1%进度打印一次日志，确保实时更新
                    let progressPercent = Int(downloadProgress.progress * 100)
                    if progressPercent % 1 == 0 && progressPercent > 0 {
                        print("📊 [下载进度] \(request.name): \(progressPercent)% (\(downloadProgress.formattedSize)) - 速度: \(downloadProgress.formattedSpeed)")
                    }
                    
                    // 强制触发UI更新 
                    request.objectWillChange.send()
                    request.runtime.objectWillChange.send()
                }
            },
            completion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let downloadResult):
                        // 确保进度显示为100%
                        request.runtime.updateProgress(
                            completed: downloadResult.fileSize,
                            total: downloadResult.fileSize
                        )
                        request.runtime.status = .completed
                        // ✅ 添加localFilePath赋值
                        request.localFilePath = downloadResult.fileURL.path
                        self.completedRequests.insert(request.id)
                        print("✅ [下载完成] \(request.name) 已保存到: \(downloadResult.fileURL.path)")
                        print("📊 [文件信息] 大小: \(ByteCountFormatter().string(fromByteCount: downloadResult.fileSize))")
                        // ✅ 立即持久化保存，确保重启后仍显示安装按钮
                        self.saveDownloadTasks()
                        
                    case .failure(let error):
                        request.runtime.error = error.localizedDescription
                        request.runtime.status = .failed
                        print("❌ [下载失败] \(request.name): \(error.localizedDescription)")
                    }
                    
                    self.activeDownloads.remove(request.id)
                }
            }
        )
    }
        
    /// 检查下载是否完成
    func isCompleted(for request: DownloadRequest) -> Bool {
        return completedRequests.contains(request.id)
    }
    
    /// 获取活跃下载数量
    var activeDownloadCount: Int {
        return activeDownloads.count
    }
    
    /// 获取已完成下载数量
    var completedDownloadCount: Int {
        return completedRequests.count
    }
}

// MARK: - 数据模型

/// 下载应用信息结构
struct DownloadArchive {
    let bundleIdentifier: String
    let name: String
    let version: String
    let identifier: Int
    let iconURL: String?
    let description: String?
    
    init(bundleIdentifier: String, name: String, version: String, identifier: Int = 0, iconURL: String? = nil, description: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.identifier = identifier
        self.iconURL = iconURL
        self.description = description
    }
}

/// 下载运行时信息
class DownloadRuntime: ObservableObject {
    @Published var status: DownloadStatus = .waiting
    @Published var progress: Progress = Progress(totalUnitCount: 0)
    @Published var speed: String = ""
    @Published var error: String?
    @Published var progressValue: Double = 0.0  // 添加独立的进度值
    
    init() {
        // 初始化时不需要设置totalUnitCount，它会在updateProgress中设置
        progress.completedUnitCount = 0
    }
    
    /// 更新进度值并触发UI更新 
    func updateProgress(completed: Int64, total: Int64) {
        // 创建新的Progress对象，因为totalUnitCount是只读的
        progress = Progress(totalUnitCount: total)
        progress.completedUnitCount = completed
        progressValue = total > 0 ? Double(completed) / Double(total) : 0.0
        
        // 强制触发UI更新 
        objectWillChange.send()
        
        // 打印调试信息 
        let percent = Int(progressValue * 100)
        print("🔄 [进度更新] \(percent)% (\(ByteCountFormatter().string(fromByteCount: completed))/\(ByteCountFormatter().string(fromByteCount: total)))")
        
        // 确保UI立即更新
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

/// 下载请求
class DownloadRequest: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    let bundleIdentifier: String
    let version: String
    let name: String
    var createdAt: Date
    let package: DownloadArchive
    let versionId: String?
    @Published var localFilePath: String?
    // Hold subscriptions for forwarding child changes
    private var cancellables: Set<AnyCancellable> = []
    @Published var runtime: DownloadRuntime { didSet { bindRuntime() } }
    
    var iconURL: String? {
        return package.iconURL
    }
    
    var identifier: Int {
        return package.identifier
    }
    
    init(bundleIdentifier: String, version: String, name: String, package: DownloadArchive, versionId: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.name = name
        self.createdAt = Date()
        self.package = package
        self.versionId = versionId
        self.runtime = DownloadRuntime()
        // Bind after runtime is set
        bindRuntime()
    }
    
    // Forward inner object changes to this object so SwiftUI can refresh when runtime's @Published values change
    private func bindRuntime() {
        cancellables.removeAll()
        runtime.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// 获取下载状态提示
    var hint: String {
        if let error = runtime.error {
            return error
        }
        return switch runtime.status {
        case .waiting:
            "等待中..."
        case .downloading:
            [
                String(Int(runtime.progressValue * 100)) + "%",
                runtime.speed.isEmpty ? "" : runtime.speed,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case .paused:
            "已暂停"
        case .completed:
            "已完成"
        case .failed:
            "下载失败"
        case .cancelled:
            "已取消"
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 下载任务持久化扩展
extension UnifiedDownloadManager {
    
    /// 保存下载任务到持久化存储
    func saveDownloadTasks() {
        NSLog("💾 [UnifiedDownloadManager] 开始保存下载任务")
        
        let saveData = DownloadTasksSaveData(
            downloadRequests: downloadRequests.map { request in
                DownloadRequestSaveData(
                    id: request.id,
                    bundleIdentifier: request.bundleIdentifier,
                    version: request.version,
                    name: request.name,
                    package: request.package,
                    versionId: request.versionId,
                    runtime: DownloadRuntimeSaveData(
                        status: request.runtime.status,
                        progressValue: request.runtime.progressValue,
                        error: request.runtime.error,
                        speed: request.runtime.speed,
                        localFilePath: request.localFilePath
                    ),
                    createdAt: request.createdAt
                )
            },
            completedRequests: Array(completedRequests),
            activeDownloads: Array(activeDownloads)
        )
        
        do {
            let data = try JSONEncoder().encode(saveData)
            UserDefaults.standard.set(data, forKey: "DownloadTasks")
            UserDefaults.standard.synchronize()
            NSLog("✅ [UnifiedDownloadManager] 下载任务保存成功，共\(downloadRequests.count)个任务")
        } catch {
            NSLog("❌ [UnifiedDownloadManager] 下载任务保存失败: \(error)")
        }
    }
    
    /// 从持久化存储恢复下载任务
    func restoreDownloadTasks() {
        NSLog("🔄 [UnifiedDownloadManager] 开始恢复下载任务")
        
        guard let data = UserDefaults.standard.data(forKey: "DownloadTasks") else {
            NSLog("ℹ️ [UnifiedDownloadManager] 没有找到保存的下载任务")
            return
        }
        
        do {
            let saveData = try JSONDecoder().decode(DownloadTasksSaveData.self, from: data)
            
            // 恢复下载请求
            downloadRequests = saveData.downloadRequests.map { saveRequest in
                let request = DownloadRequest(
                    bundleIdentifier: saveRequest.bundleIdentifier,
                    version: saveRequest.version,
                    name: saveRequest.name,
                    package: saveRequest.package,
                    versionId: saveRequest.versionId
                )
                
                // 恢复运行时状态
                request.runtime.status = saveRequest.runtime.status
                request.runtime.progressValue = saveRequest.runtime.progressValue
                request.runtime.error = saveRequest.runtime.error
                request.runtime.speed = saveRequest.runtime.speed
                request.localFilePath = saveRequest.runtime.localFilePath
                request.createdAt = saveRequest.createdAt
                
                return request
            }
            
            // 恢复集合
            completedRequests = Set(saveData.completedRequests)
            activeDownloads = Set(saveData.activeDownloads)
            
            NSLog("✅ [UnifiedDownloadManager] 下载任务恢复成功，共\(downloadRequests.count)个任务")
            
            // 检查并恢复下载状态
            checkAndResumeDownloads()
            
        } catch {
            NSLog("❌ [UnifiedDownloadManager] 下载任务恢复失败: \(error)")
        }
    }
    
    /// 暂停所有下载任务
    func pauseAllDownloads() {
        NSLog("⏸️ [UnifiedDownloadManager] 暂停所有下载任务")
        
        for request in downloadRequests {
            if request.runtime.status == .downloading {
                request.runtime.status = .paused
                activeDownloads.remove(request.id)
                NSLog("⏸️ [UnifiedDownloadManager] 已暂停: \(request.name)")
            }
        }
        
        // 保存状态
        saveDownloadTasks()
    }
    
    /// 检查并恢复下载
    private func checkAndResumeDownloads() {
        for request in downloadRequests {
            // 检查本地文件是否存在
            if let localFilePath = request.localFilePath,
               FileManager.default.fileExists(atPath: localFilePath) {
                // 只要文件存在且未标记完成，则标记为已完成
                if request.runtime.status != .completed {
                    request.runtime.status = .completed
                    completedRequests.insert(request.id)
                    activeDownloads.remove(request.id)
                    NSLog("✅ [UnifiedDownloadManager] 标记为已完成(文件存在): \(request.name)")
                }
                // 确保已完成状态的文件也在completedRequests中
                if !completedRequests.contains(request.id) {
                    completedRequests.insert(request.id)
                    NSLog("✅ [UnifiedDownloadManager] 补充标记为已完成: \(request.name)")
                }
            } else if request.runtime.status == .downloading {
                // 如果文件不存在但状态是下载中，标记为失败
                request.runtime.status = .failed
                request.runtime.error = "文件丢失，请重新下载"
                activeDownloads.remove(request.id)
                NSLog("❌ [UnifiedDownloadManager] 标记丢失文件为失败: \(request.name)")
            }
        }
        
        // 保存恢复后的状态
        saveDownloadTasks()
    }
}

// MARK: - 持久化数据结构
private struct DownloadTasksSaveData: Codable {
    let downloadRequests: [DownloadRequestSaveData]
    let completedRequests: [UUID]
    let activeDownloads: [UUID]
}

private struct DownloadRequestSaveData: Codable {
    let id: UUID
    let bundleIdentifier: String
    let version: String
    let name: String
    let packageIdentifier: Int // 只保存package的identifier
    let packageIconURL: String? // 只保存package的iconURL
    let versionId: String?
    let runtime: DownloadRuntimeSaveData
    var createdAt: Date
    
    init(id: UUID, bundleIdentifier: String, version: String, name: String, package: DownloadArchive, versionId: String?, runtime: DownloadRuntimeSaveData, createdAt: Date) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.name = name
        self.packageIdentifier = package.identifier
        self.packageIconURL = package.iconURL
        self.versionId = versionId
        self.runtime = runtime
        self.createdAt = createdAt
    }
    
    var package: DownloadArchive {
        return DownloadArchive(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: version,
            identifier: packageIdentifier,
            iconURL: packageIconURL
        )
    }
}

private struct DownloadRuntimeSaveData: Codable {
    let status: DownloadStatus
    let progressValue: Double
    let error: String?
    let speed: String
    let localFilePath: String?
}
