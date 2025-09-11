//
//  AppearanceView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//

import SwiftUI
import NimbleViews

struct AppearanceView: View {
	@AppStorage("Feather.libraryCellAppearance") private var _libraryCellAppearance: Int = 0
	
	private let _libraryCellAppearanceMethods: [String] = [
		.localized("标准"),
		.localized("药丸")
	]
	
	@AppStorage("Feather.storeCellAppearance") private var _storeCellAppearance: Int = 1
	
	private let _storeCellAppearanceMethods: [String] = [
		.localized("标准"),
		.localized("大描述")
	]
	
	@AppStorage("Feather.accentColor") private var _selectedAccentColor: Int = 0
	@StateObject private var accentColorManager = AccentColorManager.shared
	@ObservedObject private var themeManager = ThemeManager.shared
	
    @AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
    private var _ignoreSolariumLinkedOnCheck: Bool = false
    
	private let _accentColors: [(name: String, color: Color)] = [
		(.localized("默认"), Color(red: 0x53/255, green: 0x94/255, blue: 0xF7/255)),
		(.localized("樱桃"), Color(red: 0xFF/255, green: 0x8B/255, blue: 0x92/255)),
		(.localized("红色"), .red),
		(.localized("橙色"), .orange),
		(.localized("黄色"), .yellow),
		(.localized("绿色"), .green),
		(.localized("蓝色"), .blue),
		(.localized("紫色"), .purple),
		(.localized("粉色"), .pink),
		(.localized("靛蓝"), .indigo),
		(.localized("薄荷"), .mint),
		(.localized("青色"), .cyan),
		(.localized("蓝绿"), .teal)
	]
	
	private var currentAccentColor: Color {
		accentColorManager.currentAccentColor
	}

    var body: some View {
        NBList(.localized("外观")) {
            
            // 主题设置部分
            NBSection(.localized("主题")) {
                _themePreview()
                Picker(.localized("外观"), selection: Binding(
                    get: { themeManager.selectedTheme },
                    set: { themeManager.selectedTheme = $0 }
                )) {
                    ForEach(ThemeMode.allCases, id: \.self) { theme in
                        HStack {
                            Image(systemName: theme == .light ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(theme == .light ? .orange : .blue)
                            Text(theme.rawValue)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(.localized("为整个应用选择浅色或深色外观。"))
            }
            
            if #available(iOS 19.0, *) {
                NBSection(.localized("测试")) {
					Toggle(.localized("启用IOS26液态玻璃"), isOn: $_ignoreSolariumLinkedOnCheck)
				} footer: {
					Text(.localized("启用液态玻璃效果，需要重启应用才能生效。"))
                }
            }
			
			NBSection(.localized("源")) {
                _storePreview()
				Picker(.localized("商店单元格外观"), selection: $_storeCellAppearance) {
					ForEach(_storeCellAppearanceMethods.indices, id: \.description) { index in
						Text(_storeCellAppearanceMethods[index]).tag(index)
					}
				}
				.pickerStyle(.inline)
                .labelsHidden()
			}
			
			NBSection(.localized("强调色")) {
				_accentColorPreview()
				Picker(.localized("强调色"), selection: $_selectedAccentColor) {
					ForEach(_accentColors.indices, id: \.description) { index in
						HStack {
							Circle()
								.fill(_accentColors[index].color)
								.frame(width: 20, height: 20)
							Text(_accentColors[index].name)
						}
						.tag(index)
					}
				}
				.pickerStyle(.inline)
				.labelsHidden()
			}
		}
		.onChange(of: _selectedAccentColor) { _ in
			accentColorManager.updateGlobalTintColor()
		}
        .onChange(of: _ignoreSolariumLinkedOnCheck) { _ in
            UIApplication.shared.suspendAndReopen()
        }
    }
	
	@ViewBuilder
	private func _libraryPreview() -> some View {
		HStack(spacing: 9) {
			Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
				.appIconStyle(size: 57)
			
			NBTitleWithSubtitleView(
				title: Bundle.main.name,
				subtitle: "\(Bundle.main.version) • \(Bundle.main.bundleIdentifier ?? "")",
				linelimit: 0
			)
			
			FRExpirationPillView(
				title: .localized("安装"),
				showOverlay: _libraryCellAppearance == 0,
				expiration: Date.now.expirationInfo()
			).animation(.spring, value: _libraryCellAppearance)
		}
	}
    
    @ViewBuilder
    private func _storePreview() -> some View {
        VStack {
            HStack(spacing: 9) {
                Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
                    .appIconStyle(size: 57)
                
                NBTitleWithSubtitleView(
                    title: Bundle.main.name,
                    subtitle: "\(Bundle.main.version) • " + .localized("遇到问题,联系pxx917144686"),
                    linelimit: 0
                )
            }
            
            if _storeCellAppearance != 0 {
                Text(.localized("遇到问题,联系pxx917144686"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(18)
                    .padding(.top, 2)
            }
        }
        .animation(.spring, value: _storeCellAppearance)
    }
	
	@ViewBuilder
	private func _accentColorPreview() -> some View {
		HStack(spacing: 9) {
			Circle()
				.fill(currentAccentColor)
				.frame(width: 57, height: 57)
			
			NBTitleWithSubtitleView(
				title: .localized("色调"),
				subtitle: .localized("这是当前的色调"),
				linelimit: 0
			)
		}
	}
	
	@ViewBuilder
	private func _themePreview() -> some View {
		HStack(spacing: 9) {
			// 主题图标
			ZStack {
				RoundedRectangle(cornerRadius: 12)
					.fill(themeManager.backgroundColor)
					.frame(width: 57, height: 57)
					.overlay(
						RoundedRectangle(cornerRadius: 12)
							.stroke(themeManager.selectedTheme == .dark ? 
								   ModernDarkColors.borderPrimary : 
								   Color.gray.opacity(0.3), lineWidth: 1)
					)
				
				Image(systemName: themeManager.selectedTheme == .light ? "sun.max.fill" : "moon.fill")
					.font(.title2)
					.foregroundColor(themeManager.selectedTheme == .light ? .orange : .blue)
			}
			
			NBTitleWithSubtitleView(
				title: .localized("应用主题"),
				subtitle: themeManager.selectedTheme == .light ? 
					.localized("当前浅色模式") : 
					.localized("当前深色模式"),
				linelimit: 0
			)
		}
	}
}
