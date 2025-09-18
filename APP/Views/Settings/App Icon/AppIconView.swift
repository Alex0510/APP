
import SwiftUI

struct AltIcon: Identifiable {
	var displayName: String
	var author: String
	var key: String?
	var image: UIImage
	var id: String { key ?? displayName }
	
	init(displayName: String, author: String, key: String? = nil) {
		self.displayName = displayName
		self.author = author
		self.key = key
		self.image = AppIconView.altImage(key)
	}
}

extension AppIconView {
	
	static func altImage(_ name: String?) -> UIImage {
		// 尝试从AppIcons文件夹中加载图标
		if let iconName = name {
			// 尝试从AppIcons文件夹加载
			if let image = UIImage(named: iconName) {
				return image
			}
			
			// 尝试从Bundle路径加载AppIcons文件夹中的图标
			let appIconsPath = Bundle.main.bundleURL.appendingPathComponent("AppIcons/\(iconName).png")
			if let image = UIImage(contentsOfFile: appIconsPath.path) {
				return image
			}
		}
		
		// 如果都找不到，返回默认图标
		return UIImage(named: "AppIcon") ?? UIImage()
	}
}

struct AppIconView: View {
	@Binding var currentIcon: String?
	
	// dont translate
	var sections: [String: [AltIcon]] = [
		"Main": [
			AltIcon(displayName: "默认", author: "系统", key: nil)
		],
		"Kana": [
			AltIcon(displayName: "Kana Love", author: "Kana", key: "kana_love"),
			AltIcon(displayName: "Kana Peek", author: "Kana", key: "kana_peek")
		]
	]
	
	var body: some View {
		List {
			ForEach(sections.keys.sorted(), id: \.self) { section in
				if let icons = sections[section] {
					Section(section) {
						ForEach(icons) { icon in
							_icon(icon: icon)
						}
					}
				}
			}
		}
		.navigationTitle("应用图标")
		.onAppear {
			currentIcon = UIApplication.shared.alternateIconName
		}
	}
}

extension AppIconView {
	@ViewBuilder
	private func _icon(
		icon: AltIcon
	) -> some View {
		Button {
			UIApplication.shared.setAlternateIconName(icon.key) { _ in
				currentIcon = UIApplication.shared.alternateIconName
			}
		} label: {
			HStack(spacing: 18) {
				Image(uiImage: icon.image)
					.appIconStyle()
				
				NBTitleWithSubtitleView(
					title: icon.displayName,
					subtitle: icon.author
				)
				
				if currentIcon == icon.key {
					Image(systemName: "checkmark")
						.font(.body)
				}
			}
		}
	}
}
