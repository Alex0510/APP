//
//  Colors.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/02.
//  统一颜色定义 - 避免重复定义和类型歧义
//
import SwiftUI

// MARK: - 深色模式颜色系统
public struct ModernDarkColors {
    // 背景色系
    public static let primaryBackground = Color(red: 0.05, green: 0.05, blue: 0.08) // 深蓝黑
    public static let secondaryBackground = Color(red: 0.08, green: 0.08, blue: 0.12) // 稍亮的深蓝黑
    public static let tertiaryBackground = Color(red: 0.12, green: 0.12, blue: 0.16) // 卡片背景
    
    // 表面色系
    public static let surfacePrimary = Color(red: 0.15, green: 0.15, blue: 0.20) // 主要表面
    public static let surfaceSecondary = Color(red: 0.20, green: 0.20, blue: 0.25) // 次要表面
    public static let surfaceElevated = Color(red: 0.25, green: 0.25, blue: 0.30) // 提升表面
    
    // 文字色系
    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 0.8, green: 0.8, blue: 0.85) // 次要文字
    public static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.65) // 第三级文字
    
    // 强调色系
    public static let accentPrimary = Color.cyan
    public static let accentSecondary = Color(red: 0.0, green: 0.8, blue: 1.0) // 亮青色
    public static let accentTertiary = Color(red: 0.2, green: 0.8, blue: 0.8) // 青绿色
    
    // 边框和分割线
    public static let borderPrimary = Color(red: 0.3, green: 0.3, blue: 0.35)
    public static let borderSecondary = Color(red: 0.2, green: 0.2, blue: 0.25)
    
    // 阴影
    public static let shadowColor = Color.black.opacity(0.4)
    
    // 私有初始化器，防止外部实例化
    private init() {}
}
