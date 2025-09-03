//
//  DownloadManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import CryptoKit
import SwiftUI
#if canImport(ZipArchive)
import ZipArchive
#endif

// 为了避免与StoreRequest.swift中的类型冲突，这里使用不同的名称
struct DownloadStoreItem {
    let url: String
    let md5: String
    let sinfs: [DownloadSinfInfo]
    let metadata: DownloadAppMetadata
}

struct DownloadAppMetadata {
    let bundleId: String
    let bundleDisplayName: String
    let bundleShortVersionString: String
    let softwareVersionExternalIdentifier: String
    let softwareVersionExternalIdentifiers: [Int]?
}

struct DownloadSinfInfo {
    let id: Int
    let sinf: String
}

// IPAProcessor类定义在IPAProcessor.swift中
#if canImport(IPAProcessor)
// 使用外部IPAProcessor
#else
// IPA处理器实现
class IPAProcessor {
    static let shared = IPAProcessor()
    
    private init() {}
    
    /// 处理IPA文件，添加SC_Info文件夹和签名信息
    func processIPA(
        at ipaPath: URL,
        withSinfs sinfs: [Any], // 使用Any类型避免编译错误
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        print("🔧 [IPA处理器] 开始处理IPA文件: \(ipaPath.path)")
        print("🔧 [IPA处理器] 签名信息数量: \(sinfs.count)")
        
        // 在后台队列中处理
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let processedIPA = try self.processIPAFile(at: ipaPath, withSinfs: sinfs)
                DispatchQueue.main.async {
                    completion(.success(processedIPA))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 处理IPA文件的核心逻辑
    private func processIPAFile(at ipaPath: URL, withSinfs sinfs: [Any]) throws -> URL {
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        print("🔧 [IPA处理器] 创建临时工作目录: \(tempDir.path)")
        
        // 解压IPA文件
        let extractedDir = try extractIPA(at: ipaPath, to: tempDir)
        print("🔧 [IPA处理器] IPA文件解压完成: \(extractedDir.path)")
        
        // 创建SC_Info文件夹和签名文件
        try createSCInfoFolder(in: extractedDir, withSinfs: sinfs)
        print("🔧 [IPA处理器] SC_Info文件夹创建完成")
        
        // 重新打包IPA文件
        let processedIPA = try repackIPA(from: extractedDir, originalPath: ipaPath)
        print("🔧 [IPA处理器] IPA文件重新打包完成: \(processedIPA.path)")
        
        return processedIPA
    }
    
    /// 解压IPA文件
    private func extractIPA(at ipaPath: URL, to tempDir: URL) throws -> URL {
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.unzipFile(atPath: ipaPath.path, toDestination: extractedDir.path)
        guard success else {
            throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "IPA解压失败"])
        }
        print("🔧 [IPA处理器] 使用ZipArchive成功解压IPA文件")
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
        
        return extractedDir
    }
    
    /// 创建SC_Info文件夹和签名文件
    private func createSCInfoFolder(in extractedDir: URL, withSinfs sinfs: [Any]) throws {
        // 查找Payload文件夹
        let payloadDir = extractedDir.appendingPathComponent("Payload")
        guard FileManager.default.fileExists(atPath: payloadDir.path) else {
            throw NSError(domain: "IPAProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到Payload文件夹"])
        }
        
        // 查找.app文件夹
        let appFolders = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appFolder = appFolders.first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "IPAProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "未找到.app文件夹"])
        }
        
        print("🔧 [IPA处理器] 找到应用文件夹: \(appFolder.lastPathComponent)")
        
        // 创建SC_Info文件夹
        let scInfoDir = appFolder.appendingPathComponent("SC_Info")
        try FileManager.default.createDirectory(at: scInfoDir, withIntermediateDirectories: true)
        print("🔧 [IPA处理器] 创建SC_Info文件夹: \(scInfoDir.path)")
        
        // 为每个sinf创建对应的.sinf文件
        for sinf in sinfs {
            // 类型检查和转换
            guard let sinfDict = sinf as? [String: Any],
                  let id = sinfDict["id"] as? Int,
                  let sinfString = sinfDict["sinf"] as? String else {
                print("⚠️ [IPA处理器] 警告: 无效的sinf数据格式")
                continue
            }
            
            let sinfFileName = "\(id).sinf"
            let sinfFilePath = scInfoDir.appendingPathComponent(sinfFileName)
            
            // 将base64编码的sinf数据转换为二进制数据
            guard let sinfData = Data(base64Encoded: sinfString) else {
                print("⚠️ [IPA处理器] 警告: 无法解码sinf ID \(id) 的数据")
                continue
            }
            
            // 写入.sinf文件
            try sinfData.write(to: sinfFilePath)
            print("🔧 [IPA处理器] 创建签名文件: \(sinfFileName) (大小: \(ByteCountFormatter().string(fromByteCount: Int64(sinfData.count))))")
        }
        
        // 创建SC_Info.plist文件（如果不存在）
        let scInfoPlistPath = scInfoDir.appendingPathComponent("SC_Info.plist")
        if !FileManager.default.fileExists(atPath: scInfoPlistPath.path) {
            try createSCInfoPlist(at: scInfoPlistPath, withSinfs: sinfs)
            print("🔧 [IPA处理器] 创建SC_Info.plist文件")
        }
        
        // 创建iTunesMetadata.plist文件（在IPA根目录）
        try createiTunesMetadataPlist(in: extractedDir, appFolder: appFolder)
        print("🔧 [IPA处理器] 创建iTunesMetadata.plist文件")
    }
    
    /// 创建SC_Info.plist文件
    private func createSCInfoPlist(at path: URL, withSinfs sinfs: [Any]) throws {
        let plistDict: [String: Any] = [
            "CFBundleIdentifier": "com.apple.itunesstored",
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0",
            "CFBundleName": "iTunes Store",
            "CFBundleDisplayName": "iTunes Store",
            "CFBundleExecutable": "itunesstored",
            "CFBundlePackageType": "APPL",
            "CFBundleSignature": "????",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "MinimumOSVersion": "9.0",
            "UIDeviceFamily": [1, 2],
            "SinfFiles": sinfs.compactMap { sinf -> String? in
                guard let sinfDict = sinf as? [String: Any],
                      let id = sinfDict["id"] as? Int else {
                    return nil
                }
                return "\(id).sinf"
            }
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: path)
    }
    
    /// 创建iTunesMetadata.plist文件
    private func createiTunesMetadataPlist(in extractedDir: URL, appFolder: URL) throws {
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        
        // 尝试从Info.plist读取应用信息
        let infoPlistPath = appFolder.appendingPathComponent("Info.plist")
        var appInfo: [String: Any] = [:]
        
        if FileManager.default.fileExists(atPath: infoPlistPath.path) {
            do {
                let infoPlistData = try Data(contentsOf: infoPlistPath)
                if let plist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] {
                    appInfo = plist
                }
            } catch {
                print("⚠️ [IPA处理器] 无法读取Info.plist: \(error)")
            }
        }
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "artistId": 0,
            "artistName": appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? "Unknown Developer",
            "bundleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "bundleVersion": appInfo["CFBundleVersion"] as? String ?? "1.0",
            "copyright": appInfo["NSHumanReadableCopyright"] as? String ?? "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": appFolder.lastPathComponent,
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? "Unknown App",
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": appInfo["CFBundleReleaseDate"] as? String ?? "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "softwareVersionExternalIdentifier": 0,
            "softwareVersionExternalIdentifiers": [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: metadataPath)
        print("🔧 [IPA处理器] 成功创建iTunesMetadata.plist，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
    }
    
    /// 重新打包IPA文件
    private func repackIPA(from extractedDir: URL, originalPath: URL) throws -> URL {
        let processedIPAPath = originalPath.deletingLastPathComponent()
            .appendingPathComponent("processed_\(originalPath.lastPathComponent)")
        
        // 使用ZipArchive重新打包IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard success else {
            throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "IPA重新打包失败"])
        }
        print("🔧 [IPA处理器] 使用ZipArchive成功重新打包IPA文件")
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
        
        // 替换原文件
        try FileManager.default.removeItem(at: originalPath)
        try FileManager.default.moveItem(at: processedIPAPath, to: originalPath)
        
        return originalPath
    }
}
#endif
/// 用于处理IPA文件下载的下载管理器，支持进度跟踪和断点续传功能
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: (DownloadProgress) -> Void] = [:]
    private var completionHandlers: [String: (Result<DownloadResult, DownloadError>) -> Void] = [:]
    private var downloadStartTimes: [String: Date] = [:]
    private var lastProgressUpdate: [String: (bytes: Int64, time: Date)] = [:]
    private var lastUIUpdate: [String: Date] = [:]
    private var downloadDestinations: [String: URL] = [:]
    private var downloadStoreItems: [String: DownloadStoreItem] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7200 // 大文件下载设置为2小时
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.networkServiceType = .default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private override init() {
        super.init()
    }
    /// 从iTunes商店下载一个IPA文件
    /// - 参数:
    ///   - appIdentifier: 应用标识符（应用ID）
    ///   - account: 用户账户信息
    ///   - destinationURL: 保存IPA文件的本地文件URL
    ///   - appVersion: 特定的应用版本（可选）
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    func downloadApp(
        appIdentifier: String,
        account: Account,
        destinationURL: URL,
        appVersion: String? = nil,
        progressHandler: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Result<DownloadResult, DownloadError>) -> Void
    ) {
        let downloadId = UUID().uuidString
        print("📥 [下载管理器] 开始下载应用: \(appIdentifier)")
        print("📥 [下载管理器] 下载ID: \(downloadId)")
        print("📥 [下载管理器] 目标路径: \(destinationURL.path)")
        print("📥 [下载管理器] 应用版本: \(appVersion ?? "最新版本")")
        print("📥 [下载管理器] 账户信息: \(account.email)")
        Task {
            do {
                print("🔍 [下载管理器] 正在获取下载信息...")
                // 首先从商店API获取下载信息
                let downloadResponse = try await StoreRequest.shared.download(
                    appIdentifier: appIdentifier,
                    directoryServicesIdentifier: account.dsPersonId,
                    appVersion: appVersion
                )
                guard let storeItem = downloadResponse.songList.first else {
                    let error: DownloadError = .unknownError("无法获取下载信息")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                print("✅ [下载管理器] 成功获取下载信息")
                print("   - 下载URL: \(storeItem.url)")
                print("   - MD5: \(storeItem.md5)")
                
                // 将StoreDownloadResponse转换为DownloadStoreItem
                // downloadResponse是StoreDownloadResponse，包含songList数组
                guard let firstStoreItem = downloadResponse.songList.first else {
                    let error: DownloadError = .unknownError("下载响应中没有找到应用信息")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                // 将StoreItem转换为DownloadStoreItem
                let downloadStoreItem = convertToDownloadStoreItem(from: firstStoreItem)
                
                // 开始实际的文件下载
                await startFileDownload(
                    storeItem: downloadStoreItem,
                    destinationURL: destinationURL,
                    progressHandler: progressHandler,
                    completion: completion
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
            }
        }
    }
    /// 恢复已暂停的下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    func resumeDownload(
        downloadId: String,
        progressHandler: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Result<DownloadResult, DownloadError>) -> Void
    ) {
        guard let task = downloadTasks[downloadId] else {
            completion(.failure(.downloadNotFound("下载任务未找到")))
            return
        }
        progressHandlers[downloadId] = progressHandler
        completionHandlers[downloadId] = completion
        task.resume()
    }
    /// 暂停一个下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    func pauseDownload(downloadId: String) {
        downloadTasks[downloadId]?.suspend()
    }
    /// 取消一个下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    func cancelDownload(downloadId: String) {
        downloadTasks[downloadId]?.cancel()
        cleanupDownload(downloadId: downloadId)
    }
    /// 获取当前下载进度
    /// - 参数:
    ///   - downloadId: 下载标识符
    /// - 返回: 当前进度，如果未找到下载则返回nil
    func getDownloadProgress(downloadId: String) -> DownloadProgress? {
        guard let task = downloadTasks[downloadId] else { return nil }
        return DownloadProgress(
            downloadId: downloadId,
            bytesDownloaded: task.countOfBytesReceived,
            totalBytes: task.countOfBytesExpectedToReceive,
            progress: task.countOfBytesExpectedToReceive > 0 ? 
                Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive) : 0.0,
            speed: 0, // 需要根据时间计算
            remainingTime: 0, // 需要计算
            status: task.state == .running ? .downloading : 
                   task.state == .suspended ? .paused : .completed
        )
    }
    
    /// 将StoreItem转换为DownloadStoreItem
    private func convertToDownloadStoreItem(from storeItem: Any) -> DownloadStoreItem {
        print("🔍 [转换开始] 开始解析StoreItem数据")
        print("🔍 [转换开始] StoreItem类型: \(type(of: storeItem))")
        
        // 使用反射来安全地访问属性，避免类型依赖问题
        let mirror = Mirror(reflecting: storeItem)
        
        // 提取基本字段
        var url: String = ""
        var md5: String = ""
        var bundleId: String = "unknown"
        var bundleDisplayName: String = "Unknown App"
        var bundleShortVersionString: String = "1.0"
        var softwareVersionExternalIdentifier: String = "0"
        var softwareVersionExternalIdentifiers: [Int] = []
        var sinfs: [DownloadSinfInfo] = []
        
        // 遍历所有属性
        for child in mirror.children {
            guard let label = child.label else { continue }
            
            switch label {
            case "url":
                if let urlValue = child.value as? String {
                    url = urlValue
                }
            case "md5":
                if let md5Value = child.value as? String {
                    md5 = md5Value
                }
            case "metadata":
                // 处理元数据
                let metadataMirror = Mirror(reflecting: child.value)
                for metadataChild in metadataMirror.children {
                    guard let metadataLabel = metadataChild.label else { continue }
                    
                    switch metadataLabel {
                    case "bundleId":
                        if let value = metadataChild.value as? String {
                            bundleId = value
                        }
                    case "bundleDisplayName":
                        if let value = metadataChild.value as? String {
                            bundleDisplayName = value
                        }
                    case "bundleShortVersionString":
                        if let value = metadataChild.value as? String {
                            bundleShortVersionString = value
                        }
                    case "softwareVersionExternalIdentifier":
                        if let value = metadataChild.value as? String {
                            softwareVersionExternalIdentifier = value
                        }
                    case "softwareVersionExternalIdentifiers":
                        if let value = metadataChild.value as? [Int] {
                            softwareVersionExternalIdentifiers = value
                        }
                    default:
                        break
                    }
                }
            case "sinfs":
                // 处理签名信息
                if let sinfsArray = child.value as? [Any] {
                    for sinfItem in sinfsArray {
                        let sinfMirror = Mirror(reflecting: sinfItem)
                        var sinfId: Int = 0
                        var sinfString: String = ""
                        
                        for sinfChild in sinfMirror.children {
                            guard let sinfLabel = sinfChild.label else { continue }
                            
                            switch sinfLabel {
                            case "id":
                                if let value = sinfChild.value as? Int {
                                    sinfId = value
                                }
                            case "sinf":
                                if let value = sinfChild.value as? String {
                                    sinfString = value
                                }
                            default:
                                break
                            }
                        }
                        
                        if sinfId > 0 && !sinfString.isEmpty {
                            sinfs.append(DownloadSinfInfo(id: sinfId, sinf: sinfString))
                        }
                    }
                }
            default:
                break
            }
        }
        
        // 验证必要字段
        guard !url.isEmpty && !md5.isEmpty else {
            print("❌ [转换失败] 无法获取URL或MD5")
            return createDefaultDownloadStoreItem()
        }
        
        let downloadMetadata = DownloadAppMetadata(
            bundleId: bundleId,
            bundleDisplayName: bundleDisplayName,
            bundleShortVersionString: bundleShortVersionString,
            softwareVersionExternalIdentifier: softwareVersionExternalIdentifier,
            softwareVersionExternalIdentifiers: softwareVersionExternalIdentifiers
        )
        
        print("✅ [转换成功] 解析到以下数据:")
        print("   - URL: \(url)")
        print("   - MD5: \(md5)")
        print("   - Bundle ID: \(bundleId)")
        print("   - Display Name: \(bundleDisplayName)")
        
        print("✅ [转换完成] 成功创建DownloadStoreItem")
        return DownloadStoreItem(
            url: url,
            md5: md5,
            sinfs: sinfs,
            metadata: downloadMetadata
        )
    }
    
    /// 创建默认的DownloadStoreItem（用于错误情况）
    private func createDefaultDownloadStoreItem() -> DownloadStoreItem {
        return DownloadStoreItem(
            url: "",
            md5: "",
            sinfs: [],
            metadata: DownloadAppMetadata(
                bundleId: "unknown",
                bundleDisplayName: "Unknown App",
                bundleShortVersionString: "1.0",
                softwareVersionExternalIdentifier: "0",
                softwareVersionExternalIdentifiers: []
            )
        )
    }
    
    /// 开始实际的文件下载
    private func startFileDownload(
        storeItem: DownloadStoreItem,
        destinationURL: URL,
        progressHandler: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Result<DownloadResult, DownloadError>) -> Void
    ) async {
        guard let downloadURL = URL(string: storeItem.url) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidURL("无效的下载URL: \(storeItem.url)")))
            }
            return
        }
        print("🚀 [下载开始] URL: \(downloadURL.absoluteString)")
        let downloadId = UUID().uuidString
        var request = URLRequest(url: downloadURL)
        // 添加必要的请求头以确保下载稳定性
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let downloadTask = urlSession.downloadTask(with: request)
        // 记录下载开始时间和目标URL
        downloadStartTimes[downloadId] = Date()
        downloadTasks[downloadId] = downloadTask
        progressHandlers[downloadId] = progressHandler
        // 存储目标URL和storeItem信息，供delegate使用
        downloadDestinations[downloadId] = destinationURL
        downloadStoreItems[downloadId] = storeItem
        completionHandlers[downloadId] = completion
        print("📥 [下载任务] ID: \(downloadId) 已创建并启动")
        downloadTask.resume()
    }
    /// 验证下载文件的完整性
    private func verifyFileIntegrity(fileURL: URL, expectedMD5: String) -> Bool {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return false
        }
        let digest = Insecure.MD5.hash(data: fileData)
        let calculatedMD5 = digest.map { String(format: "%02hhx", $0) }.joined()
        return calculatedMD5.lowercased() == expectedMD5.lowercased()
    }
    /// 清理下载资源
    private func cleanupDownload(downloadId: String) {
        downloadTasks.removeValue(forKey: downloadId)
        progressHandlers.removeValue(forKey: downloadId)
        completionHandlers.removeValue(forKey: downloadId)
        downloadStartTimes.removeValue(forKey: downloadId)
        lastProgressUpdate.removeValue(forKey: downloadId)
        lastUIUpdate.removeValue(forKey: downloadId)
        downloadDestinations.removeValue(forKey: downloadId)
        downloadStoreItems.removeValue(forKey: downloadId)
        print("🧹 [清理完成] 下载任务 \(downloadId) 的所有资源已清理")
    }
    /// 将商店API错误映射为DownloadError
    private func mapStoreError(_ failureType: String, customerMessage: String?) -> DownloadError {
        switch failureType {
        case "INVALID_ITEM":
            return .appNotFound(customerMessage ?? "应用未找到")
        case "INVALID_LICENSE":
            return .licenseError(customerMessage ?? "许可证无效")
        case "INVALID_CREDENTIALS":
            return .authenticationError(customerMessage ?? "认证失败")
        default:
            return .unknownError(customerMessage ?? "未知错误")
        }
    }
}
// MARK: - URLSessionDownloadDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 查找此任务的下载ID
        guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let completion = completionHandlers[downloadId],
              let destinationURL = downloadDestinations[downloadId],
              let storeItem = downloadStoreItems[downloadId] else {
            print("❌ [下载完成] 无法找到下载任务ID、完成处理器、目标URL或storeItem")
            return
        }
        print("📁 [临时文件] 下载完成，临时文件位置: \(location.path)")
        print("📂 [目标位置] 将移动到: \(destinationURL.path)")
        // 检查临时文件是否存在
        guard FileManager.default.fileExists(atPath: location.path) else {
            print("❌ [临时文件] 文件不存在: \(location.path)")
            DispatchQueue.main.async {
                completion(.failure(.fileSystemError("临时下载文件不存在")))
            }
            cleanupDownload(downloadId: downloadId)
            return
        }
        // 立即移动文件到目标位置
        do {
            // 确保目标目录存在
            let targetDirectory = destinationURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 [目录创建] 已创建目标目录: \(targetDirectory.path)")
            }
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("🗑️ [文件清理] 已删除现有文件: \(destinationURL.path)")
            }
            // 移动文件
            try FileManager.default.moveItem(at: location, to: destinationURL)
            print("✅ [文件移动] 成功移动到: \(destinationURL.path)")
            // 创建包含完整信息的结果
            let result = DownloadResult(
                downloadId: downloadId,
                fileURL: destinationURL,
                fileSize: downloadTask.countOfBytesReceived,
                metadata: DownloadAppMetadata(
                    bundleId: storeItem.metadata.bundleId,
                    bundleDisplayName: storeItem.metadata.bundleDisplayName,
                    bundleShortVersionString: storeItem.metadata.bundleShortVersionString,
                    softwareVersionExternalIdentifier: storeItem.metadata.softwareVersionExternalIdentifier,
                    softwareVersionExternalIdentifiers: storeItem.metadata.softwareVersionExternalIdentifiers
                ),
                sinfs: storeItem.sinfs,
                expectedMD5: storeItem.md5
            )
            print("✅ [下载完成] 文件大小: \(ByteCountFormatter().string(fromByteCount: downloadTask.countOfBytesReceived))")
            
            // 处理IPA文件，添加SC_Info文件夹和签名信息
            print("🔧 [下载完成] 开始处理IPA文件...")
            print("🔧 [下载完成] 签名信息数量: \(storeItem.sinfs.count)")
            
            if !storeItem.sinfs.isEmpty {
                print("🔧 [下载完成] 有签名信息，开始处理IPA文件，添加签名信息...")
                IPAProcessor.shared.processIPA(at: destinationURL, withSinfs: storeItem.sinfs) { processingResult in
                    switch processingResult {
                    case .success(let processedIPA):
                        print("✅ [IPA处理] 成功处理IPA文件: \(processedIPA.path)")
                        
                        // 添加iTunesMetadata.plist
                        Task {
                            do {
                                print("🔧 [元数据处理] 开始为有签名的IPA添加iTunesMetadata.plist...")
                                // 安全解包metadata
                                guard let metadata = result.metadata else {
                                    print("❌ [元数据处理] metadata为空，无法创建iTunesMetadata.plist")
                                    DispatchQueue.main.async {
                                        completion(.success(result))
                                    }
                                    return
                                }
                                
                                print("🔧 [元数据处理] 元数据信息:")
                                print("   - Bundle ID: \(metadata.bundleId)")
                                print("   - Display Name: \(metadata.bundleDisplayName)")
                                print("   - Version: \(metadata.bundleShortVersionString)")
                                
                                // 直接生成iTunesMetadata.plist
                                let finalIPA = try await self.generateiTunesMetadata(
                                    for: processedIPA.path,
                                    bundleId: metadata.bundleId,
                                    displayName: metadata.bundleDisplayName,
                                    version: metadata.bundleShortVersionString,
                                    externalVersionId: Int(metadata.softwareVersionExternalIdentifier) ?? 0,
                                    externalVersionIds: metadata.softwareVersionExternalIdentifiers
                                )
                                
                                print("✅ [元数据处理] 成功生成iTunesMetadata.plist，最终IPA: \(finalIPA)")
                                
                                DispatchQueue.main.async {
                                    completion(.success(result))
                                }
                            } catch {
                                print("❌ [元数据处理] 生成iTunesMetadata.plist失败: \(error)")
                                DispatchQueue.main.async {
                                    completion(.success(result))
                                }
                            }
                        }
                    case .failure(let error):
                        print("❌ [IPA处理] 处理失败: \(error.localizedDescription)")
                        // 即使处理失败，也返回下载结果，但记录错误
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                    }
                }
            } else {
                print("⚠️ [下载完成] 没有签名信息，直接添加iTunesMetadata.plist...")
                
                // 即使没有签名信息，也要添加iTunesMetadata.plist
                Task {
                    do {
                        print("🔧 [元数据处理] 开始为无签名的IPA添加iTunesMetadata.plist...")
                        // 安全解包metadata
                        guard let metadata = result.metadata else {
                            print("❌ [元数据处理] metadata为空，无法创建iTunesMetadata.plist")
                            DispatchQueue.main.async {
                                completion(.success(result))
                            }
                            return
                        }
                        
                        print("🔧 [元数据处理] 元数据信息:")
                        print("   - Bundle ID: \(metadata.bundleId)")
                        print("   - Display Name: \(metadata.bundleDisplayName)")
                        print("   - Version: \(metadata.bundleShortVersionString)")
                        
                        // 直接生成iTunesMetadata.plist
                        let finalIPA = try await generateiTunesMetadata(
                            for: result.fileURL.path,
                            bundleId: metadata.bundleId,
                            displayName: metadata.bundleDisplayName,
                            version: metadata.bundleShortVersionString,
                            externalVersionId: Int(metadata.softwareVersionExternalIdentifier) ?? 0,
                            externalVersionIds: metadata.softwareVersionExternalIdentifiers
                        )
                        
                        print("✅ [元数据处理] 成功生成iTunesMetadata.plist，最终IPA: \(finalIPA)")
                        
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                    } catch {
                        print("❌ [元数据处理] 生成iTunesMetadata.plist失败: \(error)")
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                    }
                }
            }
        } catch {
            print("❌ [文件移动失败] \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.fileSystemError("文件移动失败: \(error.localizedDescription)")))
            }
        }
        cleanupDownload(downloadId: downloadId)
    }
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // 查找此任务的下载ID
        guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let progressHandler = progressHandlers[downloadId],
              let startTime = downloadStartTimes[downloadId] else {
            return
        }
        let currentTime = Date()
        // 计算下载速度
        var speed: Double = 0.0
        var remainingTime: TimeInterval = 0.0
        if let lastUpdate = lastProgressUpdate[downloadId] {
            let timeDiff = currentTime.timeIntervalSince(lastUpdate.time)
            if timeDiff > 0 {
                let bytesDiff = totalBytesWritten - lastUpdate.bytes
                speed = Double(bytesDiff) / timeDiff
            }
        } else {
            // 首次更新，使用总体平均速度
            let totalTime = currentTime.timeIntervalSince(startTime)
            if totalTime > 0 {
                speed = Double(totalBytesWritten) / totalTime
            }
        }
        // 计算剩余时间
        if speed > 0 && totalBytesExpectedToWrite > totalBytesWritten {
            let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
            remainingTime = Double(remainingBytes) / speed
        }
        let progressValue = totalBytesExpectedToWrite > 0 ? 
            Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        let progress = DownloadProgress(
            downloadId: downloadId,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            progress: progressValue,
            speed: speed,
            remainingTime: remainingTime,
            status: .downloading
        )
        // 修复UI更新频率控制逻辑，确保进度实时更新
        let lastUIUpdateTime = lastUIUpdate[downloadId] ?? Date.distantPast
        let shouldUpdate = currentTime.timeIntervalSince(lastUIUpdateTime) >= 0.1 || progressValue >= 1.0
        // 更新进度记录（在UI更新判断之后）
        lastProgressUpdate[downloadId] = (bytes: totalBytesWritten, time: currentTime)
        if shouldUpdate {
            lastUIUpdate[downloadId] = currentTime
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }
    }
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let completion = completionHandlers[downloadId] else {
            return
        }
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(.networkError(error)))
            }
        }
        cleanupDownload(downloadId: downloadId)
    }
}
// MARK: - 下载模型
/// 下载状态
enum DownloadStatus: String, Codable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

/// 下载进度信息
struct DownloadProgress {
    let downloadId: String
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let progress: Double // 0.0 到 1.0
    let speed: Double // 字节/秒
    let remainingTime: TimeInterval // 秒
    let status: DownloadStatus
    var formattedProgress: String {
        return String(format: "%.1f%%", progress * 100)
    }
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: bytesDownloaded)) / \(formatter.string(fromByteCount: totalBytes))"
    }
    var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
    var formattedRemainingTime: String {
        if remainingTime <= 0 {
            return "--:--"
        }
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

/// 下载结果
struct DownloadResult {
    let downloadId: String
    let fileURL: URL
    let fileSize: Int64
    var metadata: DownloadAppMetadata?
    var sinfs: [DownloadSinfInfo]?
    var expectedMD5: String?
    var isIntegrityValid: Bool {
        guard let expectedMD5 = expectedMD5,
              let fileData = try? Data(contentsOf: fileURL) else {
            return false
        }
        let digest = Insecure.MD5.hash(data: fileData)
        let calculatedMD5 = digest.map { String(format: "%02hhx", $0) }.joined()
        return calculatedMD5.lowercased() == expectedMD5.lowercased()
    }
}
// 数据模型现已统一在StoreClient.swift中
/// 下载特定的错误
enum DownloadError: LocalizedError {
    case invalidURL(String)
    case appNotFound(String)
    case licenseError(String)
    case authenticationError(String)
    case downloadNotFound(String)
    case fileSystemError(String)
    case integrityCheckFailed(String)
    case networkError(Error)
    case unknownError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "无效的URL: \(message)"
        case .appNotFound(let message):
            return "应用未找到: \(message)"
        case .licenseError(let message):
            return "许可证错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        case .downloadNotFound(let message):
            return "下载未找到: \(message)"
        case .fileSystemError(let message):
            return "文件系统错误: \(message)"
        case .integrityCheckFailed(let message):
            return "完整性检查失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}



// MARK: - 下载请求模型
/// 下载请求模型
struct UnifiedDownloadRequest: Identifiable, Codable {
    let id: String
    let bundleIdentifier: String
    let name: String
    let version: String
    let identifier: String
    let iconURL: String?
    let versionId: String?
    var status: DownloadStatus
    var progress: Double
    let createdAt: Date
    var completedAt: Date?
    var filePath: String?
    var errorMessage: String?
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isFailed: Bool {
        return status == .failed
    }
    
    var isDownloading: Bool {
        return status == .downloading
    }
    
    var isPaused: Bool {
        return status == .paused
    }
}

// MARK: - iTunesMetadata生成方法
extension DownloadManager {
    /// 使用ZipArchive处理IPA文件
    private func processIPAWithZipArchive(
        at ipaPath: String,
        appInfo: DownloadAppMetadata
    ) async throws -> String {
        print("🔧 [ZipArchive] 开始处理IPA文件: \(ipaPath)")
        print("🔧 [ZipArchive] 应用信息:")
        print("   - Bundle ID: \(appInfo.bundleId)")
        print("   - Display Name: \(appInfo.bundleDisplayName)")
        print("   - Version: \(appInfo.bundleShortVersionString)")
        
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("🔧 [ZipArchive] 创建临时目录: \(tempDir.path)")
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
            print("🧹 [ZipArchive] 清理临时目录: \(tempDir.path)")
        }
        
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        print("🔧 [ZipArchive] 创建解压目录: \(extractedDir.path)")
        
        // 使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        print("🔧 [ZipArchive] 开始解压IPA文件...")
        let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: extractedDir.path)
        guard success else {
            throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "SSZipArchive解压失败"])
        }
        print("🔧 [ZipArchive] 成功解压IPA文件")
        
        // 创建iTunesMetadata.plist
        print("🔧 [ZipArchive] 开始创建iTunesMetadata.plist...")
        try createiTunesMetadataPlist(in: extractedDir, appInfo: appInfo)
        print("🔧 [ZipArchive] 成功创建iTunesMetadata.plist")
        
        // 重新打包IPA文件
        print("🔧 [ZipArchive] 开始重新打包IPA文件...")
        let processedIPAPath = URL(fileURLWithPath: ipaPath).deletingLastPathComponent()
            .appendingPathComponent("processed_\(URL(fileURLWithPath: ipaPath).lastPathComponent)")
        
        let repackSuccess = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard repackSuccess else {
            throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "SSZipArchive重新打包失败"])
        }
        print("🔧 [ZipArchive] 成功重新打包IPA文件: \(processedIPAPath.path)")
        
        // 替换原文件
        print("🔧 [ZipArchive] 替换原文件...")
        try FileManager.default.removeItem(at: URL(fileURLWithPath: ipaPath))
        try FileManager.default.moveItem(at: processedIPAPath, to: URL(fileURLWithPath: ipaPath))
        print("✅ [ZipArchive] 成功替换原文件")
        
        return ipaPath
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
    }
    
    /// 创建iTunesMetadata.plist文件
    private func createiTunesMetadataPlist(in extractedDir: URL, appInfo: DownloadAppMetadata) throws {
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        print("🔧 [ZipArchive] 准备创建iTunesMetadata.plist: \(metadataPath.path)")
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": appInfo.bundleId,
            "artistId": 0,
            "artistName": appInfo.bundleDisplayName,
            "bundleId": appInfo.bundleId,
            "bundleVersion": appInfo.bundleShortVersionString,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(appInfo.bundleDisplayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo.bundleDisplayName,
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": appInfo.bundleId,
            "softwareVersionExternalIdentifier": Int(appInfo.softwareVersionExternalIdentifier) ?? 0,
            "softwareVersionExternalIdentifiers": appInfo.softwareVersionExternalIdentifiers ?? [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        print("🔧 [ZipArchive] 构建的元数据字典包含 \(metadataDict.count) 个字段")
        print("🔧 [ZipArchive] 关键字段值:")
        print("   - appleId: \(metadataDict["appleId"] ?? "nil")")
        print("   - artistName: \(metadataDict["artistName"] ?? "nil")")
        print("   - bundleId: \(metadataDict["bundleId"] ?? "nil")")
        print("   - bundleVersion: \(metadataDict["bundleVersion"] ?? "nil")")
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        print("🔧 [ZipArchive] 成功序列化plist数据，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
        
        try plistData.write(to: metadataPath)
        print("🔧 [ZipArchive] 成功写入iTunesMetadata.plist到: \(metadataPath.path)")
        
        // 验证文件是否真的被创建了
        if FileManager.default.fileExists(atPath: metadataPath.path) {
            let fileSize = try FileManager.default.attributesOfItem(atPath: metadataPath.path)[.size] as? Int64 ?? 0
            print("✅ [ZipArchive] iTunesMetadata.plist文件确认存在，大小: \(ByteCountFormatter().string(fromByteCount: fileSize))")
        } else {
            print("❌ [ZipArchive] iTunesMetadata.plist文件创建失败，文件不存在")
        }
    }
    
    /// 为IPA文件生成iTunesMetadata.plist - 强制确保每个IPA都包含元数据
    /// - Parameters:
    ///   - ipaPath: IPA文件路径
    ///   - bundleId: 应用包ID
    ///   - displayName: 应用显示名称
    ///   - version: 应用版本
    ///   - externalVersionId: 外部版本ID
    ///   - externalVersionIds: 外部版本ID数组
    /// - Returns: 处理后的IPA文件路径
    private func generateiTunesMetadata(
        for ipaPath: String,
        bundleId: String,
        displayName: String,
        version: String,
        externalVersionId: Int,
        externalVersionIds: [Int]?
    ) async throws -> String {
        print("🔧 [iTunesMetadata] 开始为IPA文件强制生成iTunesMetadata.plist: \(ipaPath)")
        print("🔧 [iTunesMetadata] 参数信息:")
        print("   - Bundle ID: \(bundleId)")
        print("   - Display Name: \(displayName)")
        print("   - Version: \(version)")
        print("   - External Version ID: \(externalVersionId)")
        print("   - External Version IDs: \(externalVersionIds ?? [])")
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": bundleId,
            "artistId": 0,
            "artistName": displayName,
            "bundleId": bundleId,
            "bundleVersion": version,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(displayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": displayName,
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": bundleId,
            "softwareVersionExternalIdentifier": externalVersionId,
            "softwareVersionExternalIdentifiers": externalVersionIds ?? [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        print("🔧 [iTunesMetadata] 构建的元数据字典包含 \(metadataDict.count) 个字段")
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        print("🔧 [iTunesMetadata] 成功生成plist数据，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
        
        // 强制使用ZipArchive处理IPA文件，确保iTunesMetadata.plist被添加
        do {
            print("🔧 [iTunesMetadata] 尝试使用ZipArchive处理IPA文件...")
            let appInfo = DownloadAppMetadata(
                bundleId: bundleId,
                bundleDisplayName: displayName,
                bundleShortVersionString: version,
                softwareVersionExternalIdentifier: String(externalVersionId),
                softwareVersionExternalIdentifiers: externalVersionIds
            )
            
            let processedIPA = try await processIPAWithZipArchive(at: ipaPath, appInfo: appInfo)
            print("✅ [iTunesMetadata] 成功使用ZipArchive处理IPA文件: \(processedIPA)")
            return processedIPA
            
        } catch {
            print("❌ [iTunesMetadata] ZipArchive处理失败: \(error)")
            print("🔄 [iTunesMetadata] 尝试备用方案：直接解压并添加iTunesMetadata.plist")
            
            // 备用方案：直接解压IPA，添加iTunesMetadata.plist，然后重新打包
            return try await fallbackAddiTunesMetadata(to: ipaPath, plistData: plistData)
        }
    }
    
    /// 备用方案：直接解压IPA并添加iTunesMetadata.plist
    private func fallbackAddiTunesMetadata(to ipaPath: String, plistData: Data) async throws -> String {
        print("🔄 [备用方案] 开始直接处理IPA文件")
        
        #if canImport(ZipArchive)
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FallbackIPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 解压IPA文件
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: extractedDir.path)
        
        guard success else {
            throw NSError(domain: "FallbackIPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "SSZipArchive解压失败"])
        }
        
        print("✅ [备用方案] IPA解压成功")
        
        // 在根目录添加iTunesMetadata.plist
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        try plistData.write(to: metadataPath)
        print("✅ [备用方案] iTunesMetadata.plist已添加到解压目录")
        
        // 重新打包IPA文件
        let processedIPAPath = ipaURL.deletingLastPathComponent()
            .appendingPathComponent("processed_\(ipaURL.lastPathComponent)")
        
        let repackSuccess = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        
        guard repackSuccess else {
            throw NSError(domain: "FallbackIPAProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "SSZipArchive重新打包失败"])
        }
        
        print("✅ [备用方案] IPA重新打包成功")
        
        // 替换原文件
        try FileManager.default.removeItem(at: ipaURL)
        try FileManager.default.moveItem(at: processedIPAPath, to: ipaURL)
        
        print("✅ [备用方案] 原IPA文件已替换为包含iTunesMetadata.plist的版本")
        return ipaURL.path
        
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "FallbackIPAProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，无法处理IPA文件"])
        #endif
    }
}