//
//  ThemeManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//

import SwiftUI

// MARK: - 圆角半径定义
struct CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Color 扩展
extension Color {
    static let surfacePrimary = Color(UIColor.systemBackground)
    static let surfaceSecondary = Color(UIColor.secondarySystemBackground)
    static let surfaceTertiary = Color(UIColor.tertiarySystemBackground)
    static let primaryAccent = Color.blue
    static let secondaryAccent = Color.cyan
    static let materialRed = Color.red
}

// MARK: - Font 扩展
extension Font {
    static let bodyLarge = Font.body
    static let bodyMedium = Font.body
    static let bodySmall = Font.caption2
    static let labelSmall = Font.caption2
    static let labelMedium = Font.caption
    static let labelLarge = Font.caption
    static let titleSmall = Font.title3
    static let titleMedium = Font.title2
    static let titleLarge = Font.title
}

// MARK: - 现代深色模式颜色方案
struct ModernDarkColors {
    static let surfacePrimary = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    static let surfaceSecondary = Color(red: 0.16, green: 0.16, blue: 0.18) // #2C2C2E
    static let surfaceElevated = Color(red: 0.20, green: 0.20, blue: 0.22) // #333336
    static let borderPrimary = Color(red: 0.33, green: 0.33, blue: 0.35) // #545456
    static let borderSecondary = Color(red: 0.24, green: 0.24, blue: 0.26) // #3D3D40
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.92, green: 0.92, blue: 0.96) // #EBEBF5
    static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.06) // #0D0D0E
    static let backgroundSecondary = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    static let primaryBackground = Color(red: 0.05, green: 0.05, blue: 0.06) // #0D0D0E
}

// MARK: - 主题模式枚举
enum ThemeMode: String, CaseIterable {
    case light = "浅色"
    case dark = "深色"
    
    /// 主题对应的强调色
    var accentColor: Color {
        switch self {
        case .light:
            return Color.blue
        case .dark:
            return Color.cyan // 深色模式使用青色作为强调色，更现代
        }
    }
}

// MARK: - 主题管理器
class ThemeManager: ObservableObject {
    /// 单例实例
    static let shared = ThemeManager()
    /// 当前选中的主题模式
    @Published var selectedTheme: ThemeMode = .light {
        didSet {
            // 当主题改变时应用新主题
            applyTheme(selectedTheme)
            // 保存主题设置到用户默认设置
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "SelectedTheme")
        }
    }
    
    /// 私有初始化方法，确保单例模式
    private init() {
        // 从用户默认设置加载保存的主题，如果没有保存过则默认为浅色模式
        if let savedTheme = UserDefaults.standard.string(forKey: "SelectedTheme"),
           let theme = ThemeMode(rawValue: savedTheme) {
            selectedTheme = theme
        }
    }
    
    /// 应用主题
    private func applyTheme(_ theme: ThemeMode) {
        switch theme {
        case .light:
            // 强制浅色模式
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            }
        case .dark:
            // 强制深色模式
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
    }
    
    /// 是否为深色模式
    var isDarkMode: Bool {
        return selectedTheme == .dark
    }
    
    /// 当前主题的强调色
    var accentColor: Color {
        return selectedTheme.accentColor
    }
    
    /// 当前主题的背景色
    var backgroundColor: Color {
        switch selectedTheme {
        case .light:
            return Color(.systemBackground)
        case .dark:
            return ModernDarkColors.backgroundPrimary
        }
    }
    
    /// 当前主题的主要文本颜色
    var primaryTextColor: Color {
        switch selectedTheme {
        case .light:
            return Color(.label)
        case .dark:
            return ModernDarkColors.textPrimary
        }
    }
    
    /// 当前主题的次要文本颜色
    var secondaryTextColor: Color {
        switch selectedTheme {
        case .light:
            return Color(.secondaryLabel)
        case .dark:
            return ModernDarkColors.textSecondary
        }
    }
}

// MARK: - Environment Key
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}



// MARK: - 浮动主题选择器（旧代码风格）
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
