
import SwiftUI

struct SigningAlternativeIconView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var _alternateIcons: [(name: String, path: String)] = []
	
	var app: AppInfoPresentable
	@Binding var appIcon: UIImage?
	@Binding var isModifing: Bool
	
	var body: some View {
		NavigationView {
			List {
				if !_alternateIcons.isEmpty {
					ForEach(_alternateIcons, id: \.name) { icon in
						Button {
							appIcon = _iconUrl(icon.path)
							dismiss()
						} label: {
							_icon(icon)
						}
						.disabled(!isModifing)
					}
				} else {
					Text("未找到图标。")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			}
			.onAppear(perform: _loadAlternateIcons)
			.navigationTitle("替换图标")
			.navigationBarTitleDisplayMode(.inline)
			// .toolbar removed for iOS 15 compatibility
		}
	}
}

extension SigningAlternativeIconView {
	@ViewBuilder
	private func _icon(_ icon: (name: String, path: String)) -> some View {
		HStack(spacing: 12) {
			if let image = _iconUrl(icon.path) {
				Image(uiImage: image)
					.appIconStyle(size: 32)
			}
			
			Text(icon.name)
				.font(.headline)
				.foregroundColor(.primary)
		}
		.padding(.vertical, 4)
	}
	
	
	private func _iconUrl(_ path: String) -> UIImage? {
		guard let app = Storage.shared.getAppDirectory(for: app) else {
			return nil
		}
		return UIImage(contentsOfFile: app.appendingPathComponent(path).relativePath)
	}
	
	private func _loadAlternateIcons() {
		guard let appDirectory = Storage.shared.getAppDirectory(for: app) else { return }
		
		let infoPlistPath = appDirectory.appendingPathComponent("Info.plist")
		guard
			let infoPlist = NSDictionary(contentsOf: infoPlistPath),
			let iconDict = infoPlist["CFBundleIcons"] as? [String: Any],
			let alternateIconsDict = iconDict["CFBundleAlternateIcons"] as? [String: [String: Any]]
		else {
			return
		}
		
		_alternateIcons = alternateIconsDict.compactMap { (name, details) in
			if let files = details["CFBundleIconFiles"] as? [String], let path = files.first {
				return (name, path)
			}
			return nil
		}
	}
}
