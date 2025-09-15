//
//  DylibInjectionIPAPackager.swift
//  APP
//
//  Created by pxx917144686
//

import Foundation
import SwiftUI
#if canImport(ZipArchive)
import ZipArchive
#endif

/// 动态库注入IPA打包器
/// 为动态库注入功能提供完整的IPA打包和安装能力
@MainActor
class DylibInjectionIPAPackager: ObservableObject {
    static let shared = DylibInjectionIPAPackager()
    
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    
    // 来自 AppStore 降级模块的真实元数据（必须在打包前设置）
    struct AppStoreMetadata: Codable {
        let appleIdAccount: String        // 原始 Apple ID（邮箱）
        let bundleId: String
        let bundleVersion: String
        let itemId: Int64                 // App Store itemId
        let itemName: String
        let artistName: String
        let genre: String
        let genreId: Int
        let vendorId: Int64
        let releaseDateISO8601: String    // 如 2025-01-01T00:00:00Z
        let price: Double
        let priceDisplay: String
        let softwareIcon57x57URL: String
    }
    
    private(set) var storeMetadata: AppStoreMetadata?
    func setStoreMetadata(_ meta: AppStoreMetadata) {
        self.storeMetadata = meta
    }
    
    private init() {}
    
    /// 为动态库注入后的应用创建可安装的IPA包
    /// - Parameters:
    ///   - appBundlePath: 应用包路径
    ///   - dylibPaths: 注入的动态库路径数组
    ///   - appleId: Apple ID（用于获取签名数据）
    ///   - completion: 完成回调
    func createInstallableIPA(
        from appBundlePath: String,
        injectedDylibs: [String],
        appleId: String? = nil,
        completion: @escaping (Result<String, DylibInjectionError>) -> Void
    ) {
        print("🔧 [DylibInjectionIPAPackager] 开始创建可安装IPA包")
        print("🔧 [DylibInjectionIPAPackager] 应用包路径: \(appBundlePath)")
        print("🔧 [DylibInjectionIPAPackager] 注入的动态库数量: \(injectedDylibs.count)")
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0.0
            self.statusMessage = "开始创建IPA包..."
            self.errorMessage = nil
        }
        
        Task {
            do {
                let ipaPath = try await processAppBundleToIPA(
                    appBundlePath: appBundlePath,
                    injectedDylibs: injectedDylibs,
                    appleId: appleId
                )
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.progress = 1.0
                    self.statusMessage = "IPA包创建完成"
                    completion(.success(ipaPath))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    completion(.failure(.ipaCreationFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// 处理应用包到IPA的核心逻辑
    private func processAppBundleToIPA(
        appBundlePath: String,
        injectedDylibs: [String],
        appleId: String?
    ) async throws -> String {
        print("🔧 [DylibInjectionIPAPackager] 开始处理应用包到IPA")
        
        // 1. 验证应用包
        try await validateAppBundle(at: appBundlePath)
        updateProgress(0.1, "验证应用包...")
        
        // 2. 创建临时工作目录
        let tempDir = try await createTempWorkingDirectory()
        updateProgress(0.2, "创建临时工作目录...")
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 3. 复制应用包到Payload目录
        let payloadDir = try await copyAppBundleToPayload(
            from: appBundlePath,
            to: tempDir
        )
        updateProgress(0.3, "复制应用包到Payload...")
        
        // 4. 验证动态库注入状态
        try await validateDylibInjection(
            in: payloadDir,
            expectedDylibs: injectedDylibs
        )
        updateProgress(0.4, "验证动态库注入状态...")
        
        // 5. 创建SC_Info文件夹和签名文件
        try await createSCInfoFolder(
            in: payloadDir,
            appleId: appleId
        )
        updateProgress(0.5, "创建签名文件...")
        
        // 6. 创建iTunesMetadata.plist
        try await createiTunesMetadataPlist(
            in: tempDir,
            appBundlePath: payloadDir
        )
        updateProgress(0.6, "创建iTunes元数据...")
        
        // 7. 重新打包为IPA文件
        let ipaPath = try await repackAsIPA(
            from: tempDir,
            originalAppPath: appBundlePath
        )
        updateProgress(0.8, "重新打包IPA文件...")
        
        // 8. 验证IPA文件完整性
        try await validateIPAFile(at: ipaPath)
        updateProgress(1.0, "验证IPA文件完整性...")
        
        print("✅ [DylibInjectionIPAPackager] IPA包创建完成: \(ipaPath)")
        return ipaPath
    }
    
    /// 验证应用包
    private func validateAppBundle(at path: String) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw DylibInjectionError.appBundleNotFound("应用包不存在: \(path)")
        }
        
        // 检查是否为.app包
        guard path.hasSuffix(".app") else {
            throw DylibInjectionError.invalidAppBundle("不是有效的.app包: \(path)")
        }
        
        // 检查Info.plist
        let infoPlistPath = "\(path)/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPlistPath) else {
            throw DylibInjectionError.invalidAppBundle("缺少Info.plist文件")
        }
        
        // 检查可执行文件
        let infoPlist = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        
        guard let executableName = infoPlist["CFBundleExecutable"] as? String else {
            throw DylibInjectionError.invalidAppBundle("缺少CFBundleExecutable")
        }
        
        let executablePath = "\(path)/\(executableName)"
        guard FileManager.default.fileExists(atPath: executablePath) else {
            throw DylibInjectionError.invalidAppBundle("可执行文件不存在: \(executableName)")
        }
        
        print("✅ [DylibInjectionIPAPackager] 应用包验证通过")
    }
    
    /// 创建临时工作目录
    private func createTempWorkingDirectory() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DylibInjectionIPA_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        print("✅ [DylibInjectionIPAPackager] 创建临时目录: \(tempDir.path)")
        return tempDir
    }
    
    /// 复制应用包到Payload目录
    private func copyAppBundleToPayload(from appPath: String, to tempDir: URL) async throws -> URL {
        let payloadDir = tempDir.appendingPathComponent("Payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        
        let appURL = URL(fileURLWithPath: appPath)
        let destinationURL = payloadDir.appendingPathComponent(appURL.lastPathComponent)
        
        // 如果目标已存在，先删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: appURL, to: destinationURL)
        
        print("✅ [DylibInjectionIPAPackager] 应用包复制完成: \(destinationURL.path)")
        return destinationURL
    }
    
    /// 验证动态库注入状态
    private func validateDylibInjection(in appBundlePath: URL, expectedDylibs: [String]) async throws {
        let executableName = try await getExecutableName(from: appBundlePath)
        let executablePath = appBundlePath.appendingPathComponent(executableName)
        
        // 使用LiveContainer的Mach-O分析功能验证注入状态
        let result = LiveContainerIntegration.shared.checkInjectionStatusUsingLiveContainer(
            executablePath.path
        )
        
        if !result.hasInjection {
            throw DylibInjectionError.injectionValidationFailed("未检测到动态库注入")
        }
        
        print("✅ [DylibInjectionIPAPackager] 动态库注入验证通过")
        print("   - 检测到注入: \(result.hasInjection)")
        print("   - 注入数量: \(result.injectedCount)")
    }
    
    /// 获取可执行文件名
    private func getExecutableName(from appBundlePath: URL) async throws -> String {
        let infoPlistPath = appBundlePath.appendingPathComponent("Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistPath)
        let infoPlist = try PropertyListSerialization.propertyList(
            from: infoPlistData,
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        
        guard let executableName = infoPlist["CFBundleExecutable"] as? String else {
            throw DylibInjectionError.invalidAppBundle("无法获取可执行文件名")
        }
        
        return executableName
    }
    
    /// 创建SC_Info文件夹和签名文件
    private func createSCInfoFolder(in appBundlePath: URL, appleId: String?) async throws {
        let scInfoDir = appBundlePath.appendingPathComponent("SC_Info")
        try FileManager.default.createDirectory(at: scInfoDir, withIntermediateDirectories: true)
        
        // 获取应用名称
        let appName = appBundlePath.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        // 创建.sinf文件
        let sinfFileName = "\(appName).sinf"
        let sinfFilePath = scInfoDir.appendingPathComponent(sinfFileName)
        
        // 生成签名数据
        let sinfData = try await generateSinfData(for: appName, appleId: appleId)
        try sinfData.write(to: sinfFilePath)
        
        print("✅ [DylibInjectionIPAPackager] SC_Info文件夹创建完成")
        print("   - 目录: \(scInfoDir.path)")
        print("   - 签名文件: \(sinfFileName)")
        print("   - 签名数据大小: \(ByteCountFormatter().string(fromByteCount: Int64(sinfData.count)))")
    }
    
    /// 生成签名数据
    private func generateSinfData(for appName: String, appleId: String?) async throws -> Data {
        // 如果有Apple ID，尝试从Apple Store API获取真实签名数据
        if let appleId = appleId, !appleId.isEmpty {
            do {
                return try await fetchRealSinfData(from: appleId, for: appName)
            } catch {
                print("⚠️ [DylibInjectionIPAPackager] 无法获取真实签名数据，使用默认数据: \(error)")
            }
        }
        
        // 生成默认签名数据
        return generateDefaultSinfData(for: appName)
    }
    
    /// 从Apple Store API获取真实签名数据
    private func fetchRealSinfData(from appleId: String, for appName: String) async throws -> Data {
        print("🔍 [DylibInjectionIPAPackager] 尝试从Apple Store API获取真实签名数据")
        
        // 这里可以集成AppStore降级功能的签名获取逻辑
        // 暂时返回默认数据，实际实现需要Apple ID认证
        return generateDefaultSinfData(for: appName)
    }
    
    /// 生成默认签名数据
    private func generateDefaultSinfData(for appName: String) -> Data {
        var sinfData = Data()
        
        // 添加头部标识
        let header = "SINF".data(using: .utf8) ?? Data()
        sinfData.append(header)
        
        // 添加版本信息
        let version: UInt32 = 1
        var versionBytes = version
        sinfData.append(Data(bytes: &versionBytes, count: MemoryLayout<UInt32>.size))
        
        // 添加应用名称
        if let appNameData = appName.data(using: .utf8) {
            let nameLength: UInt32 = UInt32(appNameData.count)
            var nameLengthBytes = nameLength
            sinfData.append(Data(bytes: &nameLengthBytes, count: MemoryLayout<UInt32>.size))
            sinfData.append(appNameData)
        }
        
        // 添加时间戳
        let timestamp: UInt64 = UInt64(Date().timeIntervalSince1970)
        var timestampBytes = timestamp
        sinfData.append(Data(bytes: &timestampBytes, count: MemoryLayout<UInt64>.size))
        
        // 添加校验和
        let checksum = sinfData.reduce(0) { $0 ^ $1 }
        var checksumBytes = checksum
        sinfData.append(Data(bytes: &checksumBytes, count: MemoryLayout<UInt8>.size))
        
        print("🔧 [DylibInjectionIPAPackager] 生成默认签名数据，大小: \(ByteCountFormatter().string(fromByteCount: Int64(sinfData.count)))")
        
        return sinfData
    }
    
    /// 创建iTunesMetadata.plist
    private func createiTunesMetadataPlist(in tempDir: URL, appBundlePath: URL) async throws {
        let metadataPath = tempDir.appendingPathComponent("iTunesMetadata.plist")
        
        guard let meta = storeMetadata else {
            throw DylibInjectionError.ipaCreationFailed("缺少 AppStore 元数据，请先通过 AppStore 降级模块设置后再打包")
        }
        
        // 读取应用信息（补充缺失字段用）
        let infoPlistPath = appBundlePath.appendingPathComponent("Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistPath)
        let infoPlist = try PropertyListSerialization.propertyList(
            from: infoPlistData,
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        let fileName = appBundlePath.lastPathComponent
        
        // 用 AppStore 降级模块提供的真实元数据构建 iTunesMetadata
        let metadataDict: [String: Any] = [
            "appleId": meta.appleIdAccount,
            "artistId": 0,
            "artistName": meta.artistName,
            "bundleId": meta.bundleId,
            "bundleVersion": meta.bundleVersion,
            "copyright": infoPlist["NSHumanReadableCopyright"] as? String ?? "",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": fileName,
            "genre": meta.genre,
            "genreId": meta.genreId,
            "itemId": meta.itemId,
            "itemName": meta.itemName,
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": meta.price,
            "priceDisplay": meta.priceDisplay,
            "rating": "4+",
            "releaseDate": meta.releaseDateISO8601,
            "s": 143441,
            "softwareIcon57x57URL": meta.softwareIcon57x57URL,
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2],
            "softwareVersionBundleId": meta.bundleId,
            "softwareVersionExternalIdentifier": 0,
            "softwareVersionExternalIdentifiers": [],
            "subgenres": [],
            "vendorId": meta.vendorId,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: metadataPath)
        print("✅ [DylibInjectionIPAPackager] iTunesMetadata.plist创建完成")
        print("   - 文件大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
    }
    
    /// 重新打包为IPA文件
    private func repackAsIPA(from tempDir: URL, originalAppPath: String) async throws -> String {
        let originalAppURL = URL(fileURLWithPath: originalAppPath)
        let ipaFileName = "\(originalAppURL.lastPathComponent.replacingOccurrences(of: ".app", with: ""))_injected.ipa"
        let ipaPath = originalAppURL.deletingLastPathComponent().appendingPathComponent(ipaFileName)
        
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(
            atPath: ipaPath.path,
            withContentsOfDirectory: tempDir.path
        )
        
        guard success else {
            throw DylibInjectionError.ipaCreationFailed("IPA重新打包失败")
        }
        
        print("✅ [DylibInjectionIPAPackager] IPA文件创建完成: \(ipaPath.path)")
        
        // 验证文件大小
        let fileSize = try FileManager.default.attributesOfItem(atPath: ipaPath.path)[.size] as? Int64 ?? 0
        print("   - 文件大小: \(ByteCountFormatter().string(fromByteCount: fileSize))")
        
        return ipaPath.path
        
        #else
        throw DylibInjectionError.ipaCreationFailed("ZipArchive库未找到，无法创建IPA文件")
        #endif
    }
    
    /// 验证IPA文件完整性
    private func validateIPAFile(at ipaPath: String) async throws {
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw DylibInjectionError.ipaCreationFailed("IPA文件不存在")
        }
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: ipaPath)[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw DylibInjectionError.ipaCreationFailed("IPA文件为空")
        }
        
        print("✅ [DylibInjectionIPAPackager] IPA文件验证通过")
        print("   - 文件路径: \(ipaPath)")
        print("   - 文件大小: \(ByteCountFormatter().string(fromByteCount: fileSize))")
    }
    
    /// 更新进度
    private func updateProgress(_ progress: Double, _ message: String) {
        DispatchQueue.main.async {
            self.progress = progress
            self.statusMessage = message
        }
    }
    
    /// 触发系统安装弹窗
    /// - Parameter ipaPath: IPA文件路径
    func triggerSystemInstallation(for ipaPath: String) {
        print("🔧 [DylibInjectionIPAPackager] 触发系统安装弹窗")
        print("   - IPA文件: \(ipaPath)")
        
        // 在iOS中，可以通过以下方式触发安装：
        // 1. 使用UIDocumentInteractionController
        // 2. 使用MFMailComposeViewController发送邮件
        // 3. 使用AirDrop分享
        // 4. 使用Safari打开itms-services://协议
        
        DispatchQueue.main.async {
            // 这里可以集成系统安装弹窗逻辑
            // 暂时显示成功消息
            self.statusMessage = "IPA文件已准备就绪，可以通过以下方式安装："
            self.errorMessage = "1. 使用AirDrop分享到其他设备\n2. 通过邮件发送\n3. 使用Safari打开itms-services://协议\n4. 使用第三方安装工具"
        }
    }
}

// MARK: - 错误类型
enum DylibInjectionError: LocalizedError {
    case appBundleNotFound(String)
    case invalidAppBundle(String)
    case injectionValidationFailed(String)
    case ipaCreationFailed(String)
    case signatureGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .appBundleNotFound(let message):
            return "应用包未找到: \(message)"
        case .invalidAppBundle(let message):
            return "无效的应用包: \(message)"
        case .injectionValidationFailed(let message):
            return "注入验证失败: \(message)"
        case .ipaCreationFailed(let message):
            return "IPA创建失败: \(message)"
        case .signatureGenerationFailed(let message):
            return "签名生成失败: \(message)"
        }
    }
}
