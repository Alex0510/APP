//
//  IPAMetadataProcessor.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/03.
//
import Foundation
#if canImport(ZipArchive)
import ZipArchive
#endif

/// 应用元数据信息（IPAMetadataProcessor专用定义）
struct ProcessorMetadataInfo {
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

// 类型别名，使用专用定义，避免与IPAZipProcessor.swift中的AppMetadataInfo冲突
typealias MetadataInfo = ProcessorMetadataInfo

/// IPA元数据处理器，专门用于为下载的IPA文件添加iTunesMetadata.plist
class IPAMetadataProcessor {
    static let shared = IPAMetadataProcessor()
    
    private init() {}
    
    /// 为IPA文件添加iTunesMetadata.plist
    /// - Parameters:
    ///   - ipaPath: IPA文件路径
    ///   - appInfo: 应用信息
    /// - Returns: 处理后的IPA文件路径
    func addMetadataToIPA(at ipaPath: String, appInfo: MetadataInfo) async throws -> String {
        print("🔧 [IPAMetadataProcessor] 开始处理IPA文件: \(ipaPath)")
        
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAMetadata_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 解压IPA文件
        let extractedDir = try extractIPA(at: ipaPath)
        print("🔧 [IPAMetadataProcessor] IPA文件解压完成")
        
        // 添加iTunesMetadata.plist
        try addiTunesMetadata(to: extractedDir, with: appInfo)
        print("🔧 [IPAMetadataProcessor] 添加iTunesMetadata.plist完成")
        
        // 重新打包IPA文件
        let processedIPA = try repackIPA(from: extractedDir, originalPath: ipaPath)
        print("🔧 [IPAMetadataProcessor] IPA文件重新打包完成")
        
        return processedIPA
    }
    
    /// 为IPA文件添加iTunesMetadata.plist
    /// - Parameters:
    ///   - ipaPath: IPA文件路径
    ///   - appInfo: 应用信息
    /// - Returns: 处理后的IPA文件路径
    func addMetadataToIPASimple(at ipaPath: String, appInfo: MetadataInfo) async throws -> String {
        print("🔧 [IPAMetadataProcessor] 开始简化处理IPA文件: \(ipaPath)")
        
        // 创建iTunesMetadata.plist内容
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
        
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAMetadata_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 在临时目录中创建iTunesMetadata.plist
        let metadataPath = tempDir.appendingPathComponent("iTunesMetadata.plist")
        try plistData.write(to: metadataPath)
        
        print("🔧 [IPAMetadataProcessor] 成功创建iTunesMetadata.plist，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
        
        // 由于iOS上无法直接操作IPA文件内容，返回原文件路径
        // 并提示用户手动添加iTunesMetadata.plist
        print("⚠️ [IPAMetadataProcessor] iOS限制：无法直接修改IPA文件")
        print("📋 [IPAMetadataProcessor] 请手动将iTunesMetadata.plist添加到IPA文件中")
        print("📁 [IPAMetadataProcessor] iTunesMetadata.plist位置: \(metadataPath.path)")
        
        return ipaPath
    }
    
    /// 解压IPA文件
    private func extractIPA(at ipaPath: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAExtraction_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: extractedDir.path)
        guard success else {
            throw IPAMetadataError.extractionFailed("ZipArchive解压失败")
        }
        print("🔧 [IPAMetadataProcessor] 使用ZipArchive成功解压IPA文件")
        #else
        // 如果没有ZipArchive，抛出错误
        throw IPAMetadataError.extractionFailed("ZipArchive库未找到，请正确配置依赖")
        #endif
        
        return extractedDir
    }
    
    /// 添加iTunesMetadata.plist到解压的IPA目录
    private func addiTunesMetadata(to extractedDir: URL, with appInfo: MetadataInfo) throws {
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
        print("🔧 [IPAMetadataProcessor] 成功创建iTunesMetadata.plist，大小: \(ByteCountFormatter().string(fromByteCount: Int64(plistData.count)))")
    }
    
    /// 重新打包IPA文件
    private func repackIPA(from extractedDir: URL, originalPath: String) throws -> String {
        let processedIPAPath = URL(fileURLWithPath: originalPath).deletingLastPathComponent()
            .appendingPathComponent("processed_\(URL(fileURLWithPath: originalPath).lastPathComponent)")
        
        // 使用ZipArchive重新打包IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard success else {
            throw IPAMetadataError.packagingFailed("ZipArchive重新打包失败")
        }
        print("🔧 [IPAMetadataProcessor] 使用ZipArchive成功重新打包IPA文件")
        #else
        // 如果没有ZipArchive，抛出错误
        throw IPAMetadataError.packagingFailed("ZipArchive库未找到，请正确配置依赖")
        #endif
        
        // 替换原文件
        try FileManager.default.removeItem(at: URL(fileURLWithPath: originalPath))
        try FileManager.default.moveItem(at: processedIPAPath, to: URL(fileURLWithPath: originalPath))
        
        return originalPath
    }
    
    /// 使用ZipArchive重新打包IPA文件
    private func repackIPAWithZipArchive(from extractedDir: URL, to outputPath: URL) throws {
        // 使用ZipArchive重新打包IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(atPath: outputPath.path, withContentsOfDirectory: extractedDir.path)
        guard success else {
            throw IPAMetadataError.packagingFailed("ZipArchive重新打包失败")
        }
        print("🔧 [IPAMetadataProcessor] 使用ZipArchive成功重新打包IPA文件")
        #else
        // 如果没有ZipArchive，抛出错误
        throw IPAMetadataError.packagingFailed("ZipArchive库未找到，请正确配置依赖")
        #endif
    }
}

// MARK: - 错误类型
enum IPAMetadataError: Error, LocalizedError {
    case extractionFailed(String)
    case packagingFailed(String)
    case metadataCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed(let message):
            return "IPA解压失败: \(message)"
        case .packagingFailed(let message):
            return "IPA打包失败: \(message)"
        case .metadataCreationFailed(let message):
            return "元数据创建失败: \(message)"
        }
    }
}
