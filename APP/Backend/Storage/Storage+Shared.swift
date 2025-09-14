import CoreData
import OSLog
extension Storage {
	func getUuidDirectory(for app: AppInfoPresentable) -> URL? {
		guard let uuid = app.uuid else { 
			Logger.misc.error("getUuidDirectory: UUID为空，应用: \(app.name ?? "未知")")
			return nil 
		}
		
		Logger.misc.info("getUuidDirectory: UUID: \(uuid), isSigned: \(app.isSigned)")
		
		let directory = app.isSigned
		? FileManager.default.signed(uuid)
		: FileManager.default.unsigned(uuid)
		
		Logger.misc.info("getUuidDirectory: 目录路径: \(directory.path)")
		
		return directory
	}
	
	func getAppDirectory(for app: AppInfoPresentable) -> URL? {
		guard let url = getUuidDirectory(for: app) else { 
			Logger.misc.error("getAppDirectory: UUID目录为空，应用: \(app.name ?? "未知")")
			return nil 
		}
		
		Logger.misc.info("getAppDirectory: UUID目录: \(url.path)")
		
		if !FileManager.default.fileExists(atPath: url.path) {
			Logger.misc.error("getAppDirectory: UUID目录不存在: \(url.path)")
			return nil
		}
		
		if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
			Logger.misc.info("getAppDirectory: UUID目录内容: \(contents.map { $0.lastPathComponent })")
		}
		
		let result = FileManager.default.getPath(in: url, for: "app")
		if result == nil {
			Logger.misc.error("getAppDirectory: 在UUID目录中未找到.app文件")
		} else {
			Logger.misc.info("getAppDirectory: 找到.app文件: \(result!.path)")
		}
		
		return result
	}
	
	func deleteApp(for app: AppInfoPresentable) {
		do {
			if let url = getUuidDirectory(for: app) {
				try? FileManager.default.removeItem(at: url)
			}
			if let object = app as? NSManagedObject {
				context.delete(object)
			}
			saveContext()
		}
	}
	
	func getCertificate(from app: AppInfoPresentable) -> CertificatePair? {
		if let signed = app as? Signed {
			return signed.certificate
		}
		return nil
	}
}

struct AnyApp: Identifiable {
	let base: AppInfoPresentable
	var archive: Bool = false
	
	var id: String {
		base.uuid ?? UUID().uuidString
	}
}

protocol AppInfoPresentable {
	var name: String? { get }
	var version: String? { get }
	var identifier: String? { get }
	var date: Date? { get }
	var icon: String? { get }
	var uuid: String? { get }
	var isSigned: Bool { get }
}

extension Signed: AppInfoPresentable {
	var isSigned: Bool { true }
}

extension Imported: AppInfoPresentable {
	var isSigned: Bool { false }
}
