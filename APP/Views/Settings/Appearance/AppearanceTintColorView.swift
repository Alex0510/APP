
import SwiftUI
import UIKit

struct AppearanceTintColorView: View {
	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#B496DC"
	@State private var showingColorPicker = false
	@State private var selectedColor = Color(hex: "#B496DC")
	
	var body: some View {
		VStack(spacing: 20) {
			// 当前选择的颜色预览
			HStack {
				Text(.localized("整体颜色"))
					.font(.headline)
					.foregroundColor(.primary)
				
				Spacer()
				
				HStack(spacing: 12) {
					Circle()
						.fill(selectedColor)
						.frame(width: 32, height: 32)
						.overlay(
							Circle()
								.strokeBorder(Color.primary.opacity(0.2), lineWidth: 2)
						)
					
					VStack(alignment: .trailing, spacing: 2) {
						Text(selectedColorHex)
							.font(.system(.caption, design: .monospaced))
							.foregroundColor(.secondary)
						
						Text(.localized("点击选择"))
							.font(.system(.caption2))
							.foregroundColor(.secondary.opacity(0.7))
					}
				}
			}
			.padding(.horizontal, 20)
			
			// iOS原生调色板选择器
			Button(action: {
				showingColorPicker = true
			}) {
				HStack {
					Image(systemName: "paintpalette.fill")
						.font(.title2)
						.foregroundColor(selectedColor)
					
					Text(.localized("选择颜色"))
						.font(.headline)
						.foregroundColor(.primary)
					
					Spacer()
					
					Image(systemName: "chevron.right")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(.horizontal, 20)
				.padding(.vertical, 16)
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(Color(uiColor: .secondarySystemGroupedBackground))
						.overlay(
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.strokeBorder(selectedColor.opacity(0.3), lineWidth: 1)
						)
				)
			}
			.buttonStyle(PlainButtonStyle())
			.padding(.horizontal, 20)
			
			// 预设颜色快速选择
			VStack(alignment: .leading, spacing: 12) {
				Text(.localized("快速选择"))
					.font(.subheadline)
					.foregroundColor(.secondary)
					.padding(.horizontal, 20)
				
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 12) {
						ForEach(presetColors, id: \.self) { color in
							Circle()
								.fill(color)
								.frame(width: 44, height: 44)
								.overlay(
									Circle()
										.strokeBorder(
											selectedColor == color ? Color.primary : Color.clear,
											lineWidth: 3
										)
								)
								.overlay(
									selectedColor == color ? 
									Image(systemName: "checkmark")
										.font(.system(size: 16, weight: .bold))
										.foregroundColor(.white)
										.background(
											Circle()
												.fill(Color.black.opacity(0.4))
												.frame(width: 24, height: 24)
										) : nil
								)
								.onTapGesture {
									withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
										selectedColor = color
										selectedColorHex = color.toHex()
									}
									
									// 触觉反馈
									let impactFeedback = UIImpactFeedbackGenerator(style: .light)
									impactFeedback.impactOccurred()
								}
						}
					}
					.padding(.horizontal, 20)
				}
			}
		}
		.padding(.vertical, 16)
		.sheet(isPresented: $showingColorPicker) {
			ColorPickerView(selectedColor: $selectedColor, selectedColorHex: $selectedColorHex)
		}
		.onChange(of: selectedColorHex) { value in
			UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: value))
		}
		.onAppear {
			selectedColor = Color(hex: selectedColorHex)
		}
	}
	
	private let presetColors: [Color] = [
		Color(hex: "#B496DC"), // 默认
		Color(hex: "#848ef9"), // 经典
		Color(hex: "#ff7a83"), // 浆果
		Color(hex: "#4161F1"), // 酷蓝
		Color(hex: "#FF00FF"), // 紫红
		Color(hex: "#4CD964"), // 协议
		Color(hex: "#FF2D55"), // 爱读
		Color(hex: "#FF9500"), // 时钟
		Color(hex: "#4860e8"), // 特殊
		Color(hex: "#5394F7"), // 非常特殊
		Color(hex: "#e18aab"), // 艾米丽
		Color(hex: "#00CED1"), // 海洋
		Color(hex: "#228B22"), // 森林
		Color(hex: "#FF6347"), // 日落
		Color(hex: "#191970"), // 星空
		Color(hex: "#FFB6C1"), // 樱花
		Color(hex: "#98FB98"), // 薄荷
		Color(hex: "#E6E6FA"), // 薰衣草
		Color(hex: "#FF7F50"), // 珊瑚
		Color(hex: "#50C878")  // 翡翠
	]
}

// MARK: - ColorPickerView
struct ColorPickerView: View {
	@Binding var selectedColor: Color
	@Binding var selectedColorHex: String
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationView {
			VStack(spacing: 20) {
				// 当前选择的颜色预览
				VStack(spacing: 16) {
					Circle()
						.fill(selectedColor)
						.frame(width: 80, height: 80)
						.overlay(
							Circle()
								.strokeBorder(Color.primary.opacity(0.2), lineWidth: 3)
						)
					
					Text(selectedColorHex)
						.font(.system(.title3, design: .monospaced))
						.foregroundColor(.secondary)
				}
				.padding(.top, 20)
				
				// iOS原生ColorPicker
				ColorPicker(.localized("选择颜色"), selection: $selectedColor, supportsOpacity: false)
					.padding(.horizontal, 20)
				
				Spacer()
			}
			.navigationTitle(.localized("颜色选择器"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(.localized("取消")) {
						dismiss()
					}
				}
				
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(.localized("返回")) {
						selectedColorHex = selectedColor.toHex()
						dismiss()
					}
					.fontWeight(.semibold)
				}
			}
		}
		.onChange(of: selectedColor) { newColor in
			// 实时更新预览
		}
	}
}

// MARK: - Color Extensions
extension Color {
	func toHex() -> String {
		let uiColor = UIColor(self)
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		
		uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		
		let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
		
		return String(format: "#%06x", rgb).uppercased()
	}
}
