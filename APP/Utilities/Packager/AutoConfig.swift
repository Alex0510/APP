//
//  AutoConfig.swift
//  APP
//
//  自动配置：确保无需手动设置也能完成“注入 → 元数据补全 → 重签 → 分发”。
//

import Foundation

enum AutoConfig {
	/// 若未设置 UserDefaults."ElleKitDebPath"，则尝试自动探测常见路径并写入
	static func configureElleKitPathIfNeeded() {
		let key = "ElleKitDebPath"
		if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty, FileManager.default.fileExists(atPath: existing) {
			return
		}
		let candidates = [
			"/APP/ellekit.deb",
			NSHomeDirectory() + "/Downloads/ellekit.deb",
		]
		if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
			UserDefaults.standard.set(found, forKey: key)
		}
	}
	
	/// 构造并注入 AppStore 降级元数据，若外部未显式设置则自动从目标 App 的 Info.plist 推断
	/// - Parameter appBundlePath: 目标 .app 路径
	@MainActor
	static func configureStoreMetadataIfNeeded(appBundlePath: String) {
		if DylibInjectionIPAPackager.shared.storeMetadata != nil { return }
		let appURL = URL(fileURLWithPath: appBundlePath)
		let infoPlistURL = appURL.appendingPathComponent("Info.plist")
		guard FileManager.default.fileExists(atPath: infoPlistURL.path) else { return }
		guard
			let data = try? Data(contentsOf: infoPlistURL),
			let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
		else { return }
		let bundleId = (info["CFBundleIdentifier"] as? String) ?? "com.unknown.app"
		let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String) ?? "1.0"
		let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
		let artist = (info["NSHumanReadableCopyright"] as? String) ?? "Unknown Developer"
		let meta = DylibInjectionIPAPackager.AppStoreMetadata(
			appleIdAccount: UserDefaults.standard.string(forKey: "AppleIDAccount") ?? "appleid@example.com",
			bundleId: bundleId,
			bundleVersion: version,
			itemId: Int64(UserDefaults.standard.integer(forKey: "AppStoreItemID")),
			itemName: name,
			artistName: artist,
			genre: "Productivity",
			genreId: 6007,
			vendorId: Int64(UserDefaults.standard.integer(forKey: "AppStoreVendorID")),
			releaseDateISO8601: (info["CFBundleReleaseDate"] as? String) ?? "2025-01-01T00:00:00Z",
			price: 0,
			priceDisplay: "Free",
			softwareIcon57x57URL: ""
		)
		DylibInjectionIPAPackager.shared.setStoreMetadata(meta)
	}
}
