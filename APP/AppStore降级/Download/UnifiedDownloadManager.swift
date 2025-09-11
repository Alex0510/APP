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
    
    private init() {}
    
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
            guard let account = AppStore.this.selectedAccount else {
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
    let createdAt: Date
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
            .localized("等待中...")
        case .downloading:
            [
                String(Int(runtime.progressValue * 100)) + "%",
                runtime.speed.isEmpty ? "" : runtime.speed,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case .paused:
            .localized("已暂停")
        case .completed:
            .localized("已完成")
        case .failed:
            .localized("下载失败")
        case .cancelled:
            .localized("已取消")
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
        return lhs.id == rhs.id
    }
}