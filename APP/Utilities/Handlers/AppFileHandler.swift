import Foundation
import ZIPFoundation
import SwiftUI
import OSLog

final class AppFileHandler: NSObject, @unchecked Sendable {
    private let _fileManager = FileManager.default
    private let _uuid = UUID().uuidString
    private let _uniqueWorkDir: URL
    var uniqueWorkDirPayload: URL?

    private var _ipa: URL
    private let _install: Bool
    private let _download: Download?
    
    init(
        file ipa: URL,
        install: Bool = false,
        download: Download? = nil
    ) {
        self._ipa = ipa
        self._install = install
        self._download = download
        self._uniqueWorkDir = _fileManager.temporaryDirectory
            .appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
        
        super.init()
        Logger.misc.debug("已导入: \(self._ipa.lastPathComponent) ID: \(self._uuid)")
    }
    
    // 避免与 NSObject.copy 冲突，使用 performCopy
    func performCopy() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try self._fileManager.createDirectoryIfNeeded(at: self._uniqueWorkDir)
                    
                    let destinationURL = self._uniqueWorkDir.appendingPathComponent(self._ipa.lastPathComponent)

                    try self._fileManager.removeFileIfNeeded(at: destinationURL)
                    
                    try self._fileManager.copyItem(at: self._ipa, to: destinationURL)
                    self._ipa = destinationURL
                    Logger.misc.info("[\(self._uuid)] 文件已复制到: \(self._ipa.path)")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func extract() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let progress = Progress(totalUnitCount: 100)
                    
                    if self._download != nil {
                        progress.addObserver(
                            self,
                            forKeyPath: #keyPath(Progress.fractionCompleted),
                            options: [.new],
                            context: nil
                        )
                    }
                    
                    try self._fileManager.unzipItem(
                        at: self._ipa,
                        to: self._uniqueWorkDir,
                        progress: progress
                    )
                    
                    if self._download != nil {
                        progress.removeObserver(
                            self,
                            forKeyPath: #keyPath(Progress.fractionCompleted)
                        )
                    }
                    
                    self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(Progress.fractionCompleted),
           let progress = object as? Progress,
           let download = self._download {
            DispatchQueue.main.async {
                download.unpackageProgress = progress.fractionCompleted
            }
        }
    }
    
    func move() async throws {
        let destinationURL = try await _directory()
        guard let payloadURL = self.uniqueWorkDirPayload else {
            throw ImportedFileHandlerError.payloadNotFound
        }
        guard _fileManager.fileExists(atPath: payloadURL.path) else {
            throw ImportedFileHandlerError.payloadNotFound
        }
        try _fileManager.moveItem(at: payloadURL, to: destinationURL)
        Logger.misc.info("[\(self._uuid)] 已移动Payload到: \(destinationURL.path)")
        try? _fileManager.removeItem(at: _uniqueWorkDir)
    }
    
    func addToDatabase() async throws {
        let app = try await _directory()
        
        guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
            return
        }
        
        let bundle = Bundle(url: appUrl)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Storage.shared.addImported(
                uuid: _uuid,
                appName: bundle?.name,
                appIdentifier: bundle?.bundleIdentifier,
                appVersion: bundle?.version,
                appIcon: bundle?.iconFileName
            ) { _ in
                Logger.misc.info("[\(self._uuid)] 已添加到数据库")
                continuation.resume()
            }
        }
    }
    
    private func _directory() async throws -> URL {
        _fileManager.unsigned(_uuid)
    }
    
    func clean() async throws {
        try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
    }
}

private enum ImportedFileHandlerError: Error {
    case payloadNotFound
}