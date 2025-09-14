
import SwiftUI
import NimbleViews
import UIKit

struct AppearanceView: View {
	@AppStorage("Feather.userInterfaceStyle")
	private var _userIntefacerStyle: Int = UIUserInterfaceStyle.unspecified.rawValue
	
	
	@AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
	private var _ignoreSolariumLinkedOnCheck: Bool = false
	
    var body: some View {
		NBList(.localized("外观")) {
			Section {
				Picker(.localized("外观"), selection: $_userIntefacerStyle) {
					ForEach(UIUserInterfaceStyle.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { style in
						Text(style.label).tag(style.rawValue)
					}
				}
				.pickerStyle(.segmented)
			}
			
			NBSection(.localized("颜色")) {
				AppearanceTintColorView()
					.listRowInsets(EdgeInsets())
					.listRowBackground(EmptyView())
			}
			
			
			if #available(iOS 19.0, *) {
				NBSection(.localized("测试性质")) {
					Toggle(.localized("启用IOS26液态玻璃"), isOn: $_ignoreSolariumLinkedOnCheck)
				} footer: {
					Text(.localized("启用液态玻璃，需要重启APP,才能生效。"))
				}
			}
		}
		.onChange(of: _userIntefacerStyle) { value in
			if let style = UIUserInterfaceStyle(rawValue: value) {
				UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
			}
		}
		.onChange(of: _ignoreSolariumLinkedOnCheck) { _ in
			UIApplication.shared.suspendAndReopen()
		}
    }
}

