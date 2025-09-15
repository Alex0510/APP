//
//  DebExtractor.swift
//  APP
//  of pxx917144686
//  在打包阶段：从 .deb 中抽取实际的 .dylib/.framework 供注入使用（非越狱运行期不使用）
//

import Foundation
import ArArchiveKit
import SWCompression

public struct DebExtractResult {
	public let tempRoot: URL
	public let dylibFiles: [URL]
	public let frameworkDirs: [URL]
}

public enum DebExtractorError: Error, LocalizedError {
	case debNotFound(String)
	case invalidArchive(String)
	case noDataTarFound
	case extractionFailed(String)
	
	public var errorDescription: String? {
		switch self {
		case .debNotFound(let path): return "未找到 .deb: \(path)"
		case .invalidArchive(let reason): return "无效的归档: \(reason)"
		case .noDataTarFound: return ".deb 中未找到 data.tar.*"
		case .extractionFailed(let reason): return "解包失败: \(reason)"
		}
	}
}

public enum DebExtractor {
	/// 从 .deb 解包，抽取 data.tar.* 内容到临时目录，并收集可注入的 Mach-O
	/// - Parameter debPath: APP/ElleKit/ellekit.deb 的绝对或相对路径
	/// - Returns: 临时根目录、收集到的 .dylib 与 .framework 目录
	public static func extractMachOs(fromDebAt debPath: String) async throws -> DebExtractResult {
		let debURL = URL(fileURLWithPath: debPath)
		guard FileManager.default.fileExists(atPath: debURL.path) else {
			throw DebExtractorError.debNotFound(debURL.path)
		}
		// 创建临时根目录
		let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("DebExtract_\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
		
		// 读取 ar 归档（异步）
		let ar = AR(with: debURL)
		let entries = try await ar.extract()
		
		// 找到 data.tar.*
		guard let dataEntry = entries.first(where: { $0.name.hasPrefix("data.tar") }) else {
			throw DebExtractorError.noDataTarFound
		}
		let dataTarURL = tempRoot.appendingPathComponent(dataEntry.name)
		try dataEntry.content.write(to: dataTarURL)
		
		// 解压 data.tar.* 到 tempRoot/data
		let dataOut = tempRoot.appendingPathComponent("data")
		try FileManager.default.createDirectory(at: dataOut, withIntermediateDirectories: true)
		try unpackTarCompressed(at: dataTarURL, into: dataOut)
		
		// 收集候选路径
		let candidateRoots = [
			"Library/Frameworks",
			"usr/lib",
			"System/Library/Frameworks"
		]
		var dylibFiles: [URL] = []
		var frameworkDirs: [URL] = []
		
		for sub in candidateRoots {
			let root = dataOut.appendingPathComponent(sub)
			if let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
				for u in urls {
					if u.pathExtension.lowercased() == "dylib" {
						dylibFiles.append(u)
					} else if u.pathExtension.lowercased() == "framework", (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
						frameworkDirs.append(u)
					}
				}
			}
		}
		
		return DebExtractResult(tempRoot: tempRoot, dylibFiles: dylibFiles, frameworkDirs: frameworkDirs)
	}
	
	// MARK: - Helpers
	private static func unpackTarCompressed(at archiveURL: URL, into outDir: URL) throws {
		let name = archiveURL.lastPathComponent
		let data = try Data(contentsOf: archiveURL)
		let tarData: Data
		if name.hasSuffix(".gz") {
			tarData = try GzipArchive.unarchive(archive: data)
		} else if name.hasSuffix(".xz") {
			tarData = try XZArchive.unarchive(archive: data)
		} else if name.hasSuffix(".bz2") {
			// SWCompression 支持 BZip2
			tarData = try BZip2.decompress(data: data)
		} else if name.hasSuffix(".lzma") {
			// LZMA (raw) → Tar
			tarData = try LZMA.decompress(data: data)
		} else if name.hasSuffix(".tar") {
			tarData = data
		} else {
			throw DebExtractorError.invalidArchive("不支持的压缩格式: \(name)")
		}
		
		let tar = try TarContainer.open(container: tarData)
		for entry in tar {
			let path = entry.info.name
			guard !path.isEmpty else { continue }
			let dst = outDir.appendingPathComponent(path)
			switch entry.info.type {
			case .directory:
				try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
			case .regular:
				guard let fileData = entry.data else { break }
				let parent = dst.deletingLastPathComponent()
				try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
				try fileData.write(to: dst)
			default:
				break
			}
		}
	}
}
