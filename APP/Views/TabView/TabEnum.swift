import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case library
	case settings
	case certificates
	case appstore
	case downloads
	
	var title: String {
		switch self {
		case .library: 		return .localized("签名")
		case .settings: 	return .localized("设置")
		case .certificates:	return .localized("证书")
		case .appstore:		return "AppStore降级"
		case .downloads:	return "下载任务"
		}
	}
	
	var icon: String {
		switch self {
		case .library: 		return "square.grid.2x2"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .appstore:		return "arrow.down.circle"
		case .downloads:	return "tray.and.arrow.down"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .library: LibraryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("证书")) { CertificatesView() }
		case .appstore: SearchView()
		case .downloads: NBNavigationView("下载管理") { DownloadView() }
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.appstore,
			.downloads,
			.library,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}
