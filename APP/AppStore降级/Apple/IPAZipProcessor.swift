//
//  IPAZipProcessor.swift
//  Created by pxx917144686 on 2025/09/03.
//
import Foundation
#if canImport(ZipArchive)
import ZipArchive
#endif

/// 应用元数据信息（IPAZipProcessor专用定义）
struct IPAMetadataInfo {
    let bundleId: String
    let displayName: String
    let version: String
    let externalVersionId: Int
    let externalVersionIds: [Int]?
    
    init(bundleId: String, displayName: String, version: String, externalVersionId: Int = 0, externalVersionIds: [Int]? = nil) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.version = version
        self.externalVersionId = externalVersionId
        self.externalVersionIds = externalVersionIds
    }
}

// 类型别名，使用专用定义
typealias AppMetadataInfo = IPAMetadataInfo

/// IPA文件处理器，使用ZipArchive来真正处理IPA文件
class IPAZipProcessor {
    static let shared = IPAZipProcessor()
    
    private init() {}
    
    /// 为IPA文件添加iTunesMetadata.plist（使用ZipArchive）
    /// - Parameters:
    ///   - ipaPath: IPA文件路径
    ///   - appInfo: 应用信息
    /// - Returns: 处理后的IPA文件路径
    func addMetadataToIPA(at ipaPath: String, appInfo: AppMetadataInfo) async throws -> String {
        print("🔧 [IPAZipProcessor] 开始处理IPA文件: \(ipaPath)")
        
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAZip_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeDirectory(at: tempDir)
        }
        
        // 尝试使用ZipArchive处理IPA文件
        do {
            let processedIPA = try await processWithZipArchive(ipaPath: ipaPath, appInfo: appInfo, tempDir: tempDir)
            print("✅ [IPAZipProcessor] 使用ZipArchive成功处理IPA文件")
            return processedIPA
        } catch {
            print("⚠️ [IPAZipProcessor] ZipArchive处理失败: \(error)")
            print("📋 [IPAZipProcessor] 使用备用方案：保存iTunesMetadata.plist到Documents目录")
            
            // 备用方案：保存iTunesMetadata.plist到Documents目录
            return try saveMetadataToDocuments(appInfo: appInfo)
        }
    }
    
    /// 使用ZipArchive处理IPA文件
    private func processWithZipArchive(ipaPath: String, appInfo: AppMetadataInfo, tempDir: URL) async throws -> String {
        // 解压IPA文件
        let extractedDir = try extractIPA(at: ipaPath, to: tempDir)
        print("🔧 [IPAZipProcessor] IPA文件解压完成")
        
        // 添加iTunesMetadata.plist
        try addiTunesMetadata(to: extractedDir, with: appInfo)
        print("🔧 [IPAZipProcessor] 添加iTunesMetadata.plist完成")
        
        // 重新打包IPA文件
        let processedIPA = try repackIPA(from: extractedDir, originalPath: ipaPath)
        print("🔧 [IPAZipProcessor] IPA文件重新打包完成")
        
        return processedIPA
    }
    
    /// 解压IPA文件
    private func extractIPA(at ipaPath: String, to tempDir: URL) throws -> URL {
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 尝试使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: extractedDir.path)
        guard success else {
            throw IPAZipError.extractionFailed("IPA解压失败")
        }
        #else
        // 如果没有ZipArchive，尝试使用系统命令
        try extractWithSystemCommand(ipaPath: ipaPath, to: extractedDir)
        #endif
        
        return extractedDir
    }
    
    /// 使用系统命令解压IPA文件（备用方案）
    private func extractWithSystemCommand(ipaPath: String, to extractedDir: URL) throws {
        #if os(macOS)
        // macOS上使用unzip命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", ipaPath, "-d", extractedDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw IPAZipError.extractionFailed("系统命令解压失败，退出码: \(process.terminationStatus)")
        }
        #else
        // iOS上无法使用系统命令，抛出错误
        throw IPAZipError.extractionFailed("iOS上无法使用系统命令解压IPA文件")
        #endif
    }
    
    /// 添加iTunesMetadata.plist到解压的IPA目录
    private func addiTunesMetadata(to extractedDir: URL, with appInfo: AppMetadataInfo) throws {
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": appInfo.bundleId,
            "artistId": 0,
            "artistName": appInfo.displayName,
            "bundleId": appInfo.bundleId,
            "bundleVersion": appInfo.version,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(appInfo.displayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo.displayName,
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
            "softwareVersionExternalIdentifier": appInfo.externalVersionId,
            "softwareVersionExternalIdentifiers": appInfo.externalVersionIds ?? [],
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
        print("🔧 [IPAZipProcessor] 成功创建iTunesMetadata.plist，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
    }
    
    /// 重新打包IPA文件
    private func repackIPA(from extractedDir: URL, originalPath: String) throws -> String {
        let processedIPAPath = URL(fileURLWithPath: originalPath).deletingLastPathComponent()
            .appendingPathComponent("processed_\(URL(fileURLWithPath: originalPath).lastPathComponent)")
        
        // 尝试使用ZipArchive重新打包IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard success else {
            throw IPAZipError.packagingFailed("IPA重新打包失败")
        }
        #else
        // 如果没有ZipArchive，尝试使用系统命令
        try repackWithSystemCommand(from: extractedDir, to: processedIPAPath)
        #endif
        
        // 替换原文件
        try FileManager.default.removeItem(at: URL(fileURLWithPath: originalPath))
        try FileManager.default.moveItem(at: processedIPAPath, to: URL(fileURLWithPath: originalPath))
        
        return originalPath
    }
    
    /// 使用系统命令重新打包IPA文件（备用方案）
    private func repackWithSystemCommand(from extractedDir: URL, to outputPath: URL) throws {
        #if os(macOS)
        // macOS上使用zip命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", outputPath.path, "."]
        process.currentDirectoryURL = extractedDir
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw IPAZipError.packagingFailed("系统命令打包失败，退出码: \(process.terminationStatus)")
        }
        #else
        // iOS上无法使用系统命令，抛出错误
        throw IPAZipError.packagingFailed("iOS上无法使用系统命令打包IPA文件")
        #endif
    }
    
    /// 备用方案：保存iTunesMetadata.plist到Documents目录
    private func saveMetadataToDocuments(appInfo: AppMetadataInfo) throws -> String {
        let metadataDict: [String: Any] = [
            "appleId": appInfo.bundleId,
            "artistId": 0,
            "artistName": appInfo.displayName,
            "bundleId": appInfo.bundleId,
            "bundleVersion": appInfo.version,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(appInfo.displayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo.displayName,
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
            "softwareVersionExternalIdentifier": appInfo.externalVersionId,
            "softwareVersionExternalIdentifiers": appInfo.externalVersionIds ?? [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        // 保存到Documents目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let finalMetadataPath = documentsPath.appendingPathComponent("iTunesMetadata_\(appInfo.bundleId).plist")
        try plistData.write(to: finalMetadataPath)
        
        print("📁 [IPAZipProcessor] 备用方案：iTunesMetadata.plist已保存到: \(finalMetadataPath.path)")
        print("📋 [IPAZipProcessor] 请手动将此文件添加到IPA文件中")
        
        return finalMetadataPath.path
    }
}

// MARK: - 应用元数据信息
// 注意：AppMetadataInfo现在在IPAMetadataProcessor.swift中定义，避免重复
// struct AppMetadataInfo {
//     let bundleId: String
//     let displayName: String
//     let version: String
//     let externalVersionId: Int
//     let externalVersionIds: [Int]?
//     
//     init(bundleId: String, displayName: String, version: String, externalVersionId: Int = 0, externalVersionIds: [Int]? = nil) {
//         self.bundleId = bundleId
//         self.displayName = displayName
//         self.version = version
//         self.externalVersionId = externalVersionId
//         self.externalVersionIds = externalVersionIds
//     }
// }

// MARK: - 错误类型
enum IPAZipError: Error, LocalizedError {
    case extractionFailed(String)
    case packagingFailed(String)
    case libraryNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed(let message):
            return "IPA解压失败: \(message)"
        case .packagingFailed(let message):
            return "IPA打包失败: \(message)"
        case .libraryNotFound(let message):
            return "库未找到: \(message)"
        }
    }
}

// MARK: - FileManager扩展
extension FileManager {
    func removeDirectory(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
