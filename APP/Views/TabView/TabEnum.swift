//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
    case files
	case sources
	case library
	case appstoreDowngrade
	case settings
	case certificates
	case appstore
	var title: String {
		switch self {
        case .files:        return .localized("Files文件")
		case .sources:     	return .localized("第三方源")
		case .library: 		return .localized("证书签名")
		case .appstoreDowngrade: return .localized("AppStore降级")
		case .settings: 	return .localized("设置")
		case .certificates:	return .localized("证书管理")
		case .appstore: 	return .localized("APP源")
		}
	}
	
	var icon: String {
		switch self {
        case .files:        return "folder.fill"
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .appstoreDowngrade: return "arrow.down.circle.fill"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .appstore: 	return "plus.app.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
        case .files: FilesView()
		case .sources: SourcesView()
		case .library: LibraryView()
		case .appstoreDowngrade: SearchView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("证书管理")) { CertificatesView() }
		case .appstore: AppstoreView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
            .files,
            .library,
            .appstoreDowngrade,
            .appstore,
			.settings,
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}
