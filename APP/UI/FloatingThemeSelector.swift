//
//  FloatingThemeSelector.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/29.
//
import SwiftUI

struct FloatingThemeSelector: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景遮罩
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
            }
            
            // 悬浮窗内容
            if isPresented {
                VStack(spacing: 0) {
                    Spacer()
                    // 主题选择器
                    VStack(spacing: Spacing.lg) {                        
                        // 主题选项
                        HStack(spacing: Spacing.xl) {
                            // 浅色主题选项
                            FloatingThemeOption(
                                mode: .light,
                                isSelected: themeManager.selectedTheme == .light,
                                action: {
                                    themeManager.selectedTheme = .light
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isPresented = false
                                    }
                                }
                            )
                            // 深色主题选项
                            FloatingThemeOption(
                                mode: .dark,
                                isSelected: themeManager.selectedTheme == .dark,
                                action: {
                                    themeManager.selectedTheme = .dark
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isPresented = false
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.bottom, 80) // 使用固定值：底部安全区域 + 80
                }
            }
        }
    }
}

// 悬浮窗主题选项组件
struct FloatingThemeOption: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    // 使用简单的固定值替代复杂的设备检测
    let isCompactDevice = false // 默认不是紧凑设备
    
    // 根据设备类型调整尺寸
    private var cardSize: CGSize {
        // 使用固定值，不再依赖设备检测
        return CGSize(width: 100, height: 120)
    }
    
    private var fontSize: CGFloat {
        // 使用固定值，不再依赖设备检测
        return 12
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.md) {
                // 主题预览卡片 - 模拟APP搜索界面
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeBackgroundColor)
                        .frame(width: cardSize.width, height: cardSize.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? ThemeManager.shared.accentColor : Color.clear, lineWidth: 4)
                        )
                        .shadow(color: isSelected ? ThemeManager.shared.accentColor.opacity(0.4) : Color.black.opacity(0.15), radius: isSelected ? 12 : 6, x: 0, y: 4)
                    
                    // APP搜索界面预览
                    VStack(spacing: 8) {
                        // 状态栏
                        HStack {
                            Text("9:41")
                                .font(.system(size: fontSize - 2, weight: .medium))
                                .foregroundColor(themeTextColor)
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "wifi")
                                    .font(.system(size: fontSize - 2))
                                    .foregroundColor(themeTextColor)
                                Image(systemName: "battery.100")
                                    .font(.system(size: fontSize - 2))
                                    .foregroundColor(themeTextColor)
                            }
                        }
                        .frame(width: cardSize.width * 0.75)
                        .padding(.top, 6)
                        
                        // 搜索栏
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeSearchBarColor)
                            .frame(width: cardSize.width * 0.75, height: fontSize + 6)
                            .overlay(
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: fontSize - 3))
                                        .foregroundColor(themeSecondaryColor)
                                    Text("搜索")
                                        .font(.system(size: fontSize - 3))
                                        .foregroundColor(themeSecondaryColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                            )
                        
                        // 搜索结果网格 - 彩色APP图标
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                // APP图标1 - 蓝色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                                // APP图标2 - 绿色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                                // APP图标3 - 橙色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                            }
                            HStack(spacing: 4) {
                                // APP图标4 - 紫色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.purple)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                                // APP图标5 - 红色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                                // APP图标6 - 青色
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.teal)
                                    .frame(width: fontSize + 3, height: fontSize + 3)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                // 主题名称
                Text(mode == .light ? "浅色" : "深色")
                    .font(.system(size: fontSize + 2, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? ThemeManager.shared.accentColor : .primary)
                
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ThemeManager.shared.accentColor)
                        .font(.system(size: fontSize + 6))
                        .scaleEffect(1.2)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 主题相关的颜色计算属性
    private var themeBackgroundColor: Color {
        switch mode {
        case .light:
            return Color.white
        case .dark:
            return ModernDarkColors.surfacePrimary
        }
    }
    
    private var themeTextColor: Color {
        switch mode {
        case .light:
            return Color.black
        case .dark:
            return ModernDarkColors.textPrimary
        }
    }
    
    private var themeSecondaryColor: Color {
        switch mode {
        case .light:
            return Color.gray
        case .dark:
            return ModernDarkColors.textSecondary
        }
    }
    
    private var themeSearchBarColor: Color {
        switch mode {
        case .light:
            return Color.gray.opacity(0.1)
        case .dark:
            return ModernDarkColors.surfaceSecondary
        }
    }
}
