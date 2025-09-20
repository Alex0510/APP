//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
    @State private var selectedTab: TabEnum = .appstore
    @Environment(\.colorScheme) var colorScheme
    
    // 定义标签栏中显示的所有标签
    private var displayedTabs: [TabEnum] {
        return TabEnum.defaultTabs
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区域
            Group {
                switch selectedTab {
                case .library: LibraryView()
                case .settings: SettingsView()
                case .certificates: NavigationView { CertificatesView() }
                case .appstore: SearchView()
                case .downloads: NavigationView { DownloadView() }
                case .account: NavigationView { AccountManagerView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 自定义液态玻璃标签栏
            liquidGlassTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // 液态玻璃标签栏视图
    @ViewBuilder
    private func liquidGlassTabBar(selectedTab: Binding<TabEnum>) -> some View {
        HStack(spacing: 0) {
            ForEach(displayedTabs, id: \.self) { tab in
                LiquidTabButton(
                    tab: tab,
                    isSelected: selectedTab.wrappedValue == tab,
                    action: { selectedTab.wrappedValue = tab },
                    colorScheme: colorScheme
                )
                .frame(maxWidth: .infinity)
                
                if tab != displayedTabs.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            GlassMorphismBackground(colorScheme: colorScheme)
        )
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 5)
    }
}

// 液态玻璃标签按钮
struct LiquidTabButton: View {
    let tab: TabEnum
    let isSelected: Bool
    let action: () -> Void
    let colorScheme: ColorScheme
    
    // 根据颜色方案和选中状态确定文字颜色
    private var textColor: Color {
        if isSelected {
            // 选中状态下使用与背景对比度高的颜色
            return colorScheme == .dark ? .white : .blue // 浅色模式使用蓝色，深色模式使用白色
        } else {
            return .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                
                Text(tab.title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(textColor) // 使用动态计算的颜色
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        // 选中状态的液态玻璃效果
                        GlassMorphismBackground(colorScheme: colorScheme, cornerRadius: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: colorScheme == .dark ?
                                                [.white.opacity(0.5), .clear] :
                                                [.blue.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// 玻璃拟态背景
struct GlassMorphismBackground: View {
    var colorScheme: ColorScheme
    var cornerRadius: CGFloat = 25
    
    var body: some View {
        ZStack {
            // 模糊背景 - 根据颜色方案调整
            VisualEffectBlur(blurStyle: colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                .cornerRadius(cornerRadius)
            
            // 光泽效果 - 根据颜色方案调整
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [.white.opacity(0.2), .white.opacity(0.05)] :
                            [.white.opacity(0.35), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blendMode(.overlay)
            
            // 背景渐变 - 根据颜色方案调整
            LinearGradient(
                colors: colorScheme == .dark ?
                    [.blue.opacity(0.1), .clear] :
                    [.white.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(colorScheme == .dark ? .white.opacity(0.1) : .blue.opacity(0.1), lineWidth: 1)
        )
    }
}

// 视觉模糊效果 (支持iOS 13+)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// 按钮缩放动画效果
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
