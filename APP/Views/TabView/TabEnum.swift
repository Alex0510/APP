import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case sources
	case library
	case settings
	case certificates
	case appstore
	
	var title: String {
		switch self {
		case .sources:     	return .localized("第三方源")
		case .library: 		return .localized("签名")
		case .settings: 	return .localized("设置")
		case .certificates:	return .localized("证书")
		case .appstore:		return "AppStore降级"
		}
	}
	
	var icon: String {
		switch self {
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .appstore:		return "arrow.down.circle"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .sources: SourcesView()
		case .library: LibraryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("证书")) { CertificatesView() }
		case .appstore: SearchView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.appstore,
			.sources,
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
