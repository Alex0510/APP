import UIKit

extension UIUserInterfaceStyle: @retroactive CaseIterable {
	public static var allCases: [UIUserInterfaceStyle] {
		[.unspecified, .dark, .light]
	}
	
	var label: String {
		switch self {
		case .unspecified: .localized("默认")
		case .dark: .localized("深色")
		case .light: .localized("浅色")
		@unknown default: .localized("未知")
		}
	}
}
