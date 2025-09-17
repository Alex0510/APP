
import SwiftUI
import NimbleViews
import UIKit

struct AppearanceView: View {
	@EnvironmentObject var themeManager: ThemeManager
	
	@AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
	private var _ignoreSolariumLinkedOnCheck: Bool = false
	
    var body: some View {
		NBList(.localized("外观")) {
			Section {
				Picker(.localized("外观"), selection: Binding(
					get: {
						// 现在AppTheme的rawValue与UIUserInterfaceStyle的rawValue匹配，直接返回
						return themeManager.selectedTheme.rawValue
					},
					set: { newValue in
						// 现在AppTheme的rawValue与UIUserInterfaceStyle的rawValue匹配，直接转换
						if let appTheme = AppTheme(rawValue: newValue) {
							themeManager.selectedTheme = appTheme
						}
					}
				)) {
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
					Toggle(.localized("切换:液态玻璃UI"), isOn: $_ignoreSolariumLinkedOnCheck)
				} footer: {
					Text(.localized("重启APP生效。遇到问题联系pxx917144686"))
				}
			}
		}
		.onChange(of: _ignoreSolariumLinkedOnCheck) { _ in
			UIApplication.shared.suspendAndReopen()
		}
    }
}

