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
    
    func copy() async throws {
        try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
        
        let destinationURL = _uniqueWorkDir.appendingPathComponent(_ipa.lastPathComponent)

        try _fileManager.removeFileIfNeeded(at: destinationURL)
        
        try _fileManager.copyItem(at: _ipa, to: destinationURL)
        _ipa = destinationURL
        Logger.misc.info("[\(self._uuid)] 文件已复制到: \(self._ipa.path)")
    }
    
    func extract() async throws {
        let download = self._download
        
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let progress = Progress(totalUnitCount: 100)
                    
                    if let download = download {
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
                    
                    if let download = download {
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
        guard let payloadURL = uniqueWorkDirPayload else {
            throw ImportedFileHandlerError.payloadNotFound
        }
        
        let destinationURL = try await _directory()
        
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
        
        Storage.shared.addImported(
            uuid: _uuid,
            appName: bundle?.name,
            appIdentifier: bundle?.bundleIdentifier,
            appVersion: bundle?.version,
            appIcon: bundle?.iconFileName
        ) { _ in
            Logger.misc.info("[\(self._uuid)] 已添加到数据库")
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