import UIKit

extension UIUserInterfaceStyle: @retroactive CaseIterable {
	public static var allCases: [UIUserInterfaceStyle] {
		[.unspecified, .dark, .light]
	}
	
	var label: String {
		switch self {
		case .unspecified: "跟随系统"
		case .dark: "深色"
		case .light: "浅色"
		@unknown default: "未知"
		}
	}
}
