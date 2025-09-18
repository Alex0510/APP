
import SwiftUI
import UIKit

struct AppearanceView: View {
	@EnvironmentObject var themeManager: ThemeManager
	
	@AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
	private var _ignoreSolariumLinkedOnCheck: Bool = false
	
    var body: some View {
		List {
			Section {
				Picker("外观", selection: Binding(
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
			
			Section {
				AppearanceTintColorView()
					.listRowInsets(EdgeInsets())
					.listRowBackground(EmptyView())
			} header: {
				Text("颜色")
			}
			
			
			if #available(iOS 19.0, *) {
				Section {
					Toggle("切换:液态玻璃UI", isOn: $_ignoreSolariumLinkedOnCheck)
				} header: {
					Text("测试性质")
				} footer: {
					Text("重启APP生效。遇到问题联系pxx917144686")
				}
			}
		}
		.onChange(of: _ignoreSolariumLinkedOnCheck) { _ in
			// UIApplication.shared.suspendAndReopen() - not available in iOS 15
		}
    }
}

