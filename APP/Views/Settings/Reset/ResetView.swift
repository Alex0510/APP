
import SwiftUI
import NimbleViews
import Nuke
import CoreData

struct ResetView: View {
    var body: some View {
		NBList(.localized("重置")) {
			_cache()
			_coredata()
			_all()
		}
    }
	
	private func _cacheSize() -> String {
		var totalCacheSize = URLCache.shared.currentDiskUsage
		if let nukeCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			totalCacheSize += nukeCache.totalSize
		}
		return "\(ByteCountFormatter.string(fromByteCount: Int64(totalCacheSize), countStyle: .file))"
	}
	
	static func resetAlert(
		title: String,
		message: String = "",
		action: @escaping () -> Void
	) {
		let action = UIAlertAction(
			title: .localized("继续"),
			style: .destructive
		) { _ in
			action()
			UIApplication.shared.suspendAndReopen()
		}
		
		let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad
		? .alert
		: .actionSheet
		
		var msg = ""
		if !message.isEmpty { msg = message + "\n" }
		msg.append(.localized("此操作无法撤销。您确定要继续吗？"))
	
		UIAlertController.showAlertWithCancel(
			title: title,
			message: msg,
			style: style,
			actions: [action]
		)
	}
}

extension ResetView {
	@ViewBuilder
	private func _cache() -> some View {
		Section {
			Button(.localized("重置工作缓存"), systemImage: "xmark.rectangle.portrait") {
				Self.resetAlert(title: .localized("重置工作缓存")) {
					Self.clearWorkCache()
				}
			}
			
			Button(.localized("重置网络缓存"), systemImage: "xmark.rectangle.portrait") {
				Self.resetAlert(
					title: .localized("重置网络缓存"),
					message: _cacheSize()
				) {
					Self.clearNetworkCache()
				}
			}
		}
	}
	
	@ViewBuilder
	private func _coredata() -> some View {
		Section {
			Button(.localized("重置来源"), systemImage: "xmark.circle") {
				Self.resetAlert(
					title: .localized("重置来源"),
					message: Storage.shared.countContent(for: AltSource.self)
				) {
					Self.resetSources()
				}
			}
			
			Button(.localized("重置已签名应用"), systemImage: "xmark.circle") {
				Self.resetAlert(
					title: .localized("重置已签名应用"),
					message: Storage.shared.countContent(for: Signed.self)
				) {
					Self.deleteSignedApps()
				}
			}
			
			Button(.localized("重置已导入应用"), systemImage: "xmark.circle") {
				Self.resetAlert(
					title: .localized("重置已导入应用"),
					message: Storage.shared.countContent(for: Imported.self)
				) {
					Self.deleteImportedApps()
				}
			}
			
			Button(.localized("重置证书"), systemImage: "xmark.circle") {
				Self.resetAlert(
					title: .localized("重置证书"),
					message: Storage.shared.countContent(for: CertificatePair.self)
				) {
					Self.resetCertificates()
				}
			}
		}
	}
	
	@ViewBuilder
	private func _all() -> some View {
		Section {
			Button(.localized("重置设置"), systemImage: "xmark.octagon") {
				Self.resetAlert(title: .localized("重置设置")) {
					Self.resetUserDefaults()
				}
			}
			
			Button(.localized("重置全部"), systemImage: "xmark.octagon") {
				Self.resetAlert(title: .localized("重置全部")) {
					Self.resetAll()
				}
			}
		}
		.foregroundStyle(.red)
	}
}

extension ResetView {
	static func clearWorkCache() {
		let fileManager = FileManager.default
		let tmpDirectory = fileManager.temporaryDirectory
		
		if let files = try? fileManager.contentsOfDirectory(atPath: tmpDirectory.path()) {
			for file in files {
				try? fileManager.removeItem(atPath: tmpDirectory.appendingPathComponent(file).path())
			}
		}
	}
	
	static func clearNetworkCache() {
		URLCache.shared.removeAllCachedResponses()
		HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
		
		if let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
			dataCache.removeAll()
		}
		
		if let imageCache = ImagePipeline.shared.configuration.imageCache as? Nuke.ImageCache {
			imageCache.removeAll()
		}
	}
	
	static func resetSources() {
		Storage.shared.clearContext(request: AltSource.fetchRequest())
	}
	
	static func deleteSignedApps() {
		Storage.shared.clearContext(request: Signed.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.signed)
	}
	
	static func deleteImportedApps() {
		Storage.shared.clearContext(request: Imported.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.unsigned)
	}
	
	static func resetCertificates(resetAll: Bool = false) {
		if !resetAll { UserDefaults.standard.set(0, forKey: "feather.selectedCert") }
		Storage.shared.clearContext(request: CertificatePair.fetchRequest())
		try? FileManager.default.removeFileIfNeeded(at: FileManager.default.certificates)
	}
	
	static func resetUserDefaults() {
		UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
	}
	
	static func resetAll() {
		clearWorkCache()
		clearNetworkCache()
		resetSources()
		deleteSignedApps()
		deleteImportedApps()
		resetCertificates(resetAll: true)
		resetUserDefaults()
	}
}
