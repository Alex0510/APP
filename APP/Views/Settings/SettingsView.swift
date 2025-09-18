import SwiftUI
import UIKit
import Darwin

struct SettingsView: View {
    private let _githubUrl = "https://github.com/pxx917144686/APP"
    @State private var currentIcon = UIApplication.shared.alternateIconName
    @StateObject private var optionsManager = OptionsManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                
                // 高级功能区域 - 最显眼位置
                advancedFeaturesSection
                
                _feedback()
                
                appearanceSection
                
                signingSection
                
                resetSection
            }
        }
    }
}

extension SettingsView {
    
    // MARK: - 高级功能区域
    private var advancedFeaturesSection: some View {
        Section {
            Toggle(isOn: $optionsManager.options.experiment_supportLiquidGlass) {
                Label {
                    Text("切换:液态玻璃UI")
                        .font(.headline)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: "26.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        } header: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("高级功能")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        } footer: {
            Text("iOS26系统,引入的新液态玻璃!遇到问题,联系作者pxx917144686")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onChange(of: optionsManager.options.experiment_supportLiquidGlass) { _ in
            optionsManager.saveOptions()
        }
    }
    
    private var appearanceSection: some View {
        Section {
            NavigationLink(destination: AppearanceView().environmentObject(ThemeManager.shared)) {
                Label("外观", systemImage: "paintbrush")
            }
            NavigationLink(destination: AppIconView(currentIcon: $currentIcon)) {
                Label("图标", systemImage: "app.badge")
            }
        }
    }
    
    private var signingSection: some View {
        Section {
            NavigationLink(destination: CertificatesView()) {
                Label("证书", systemImage: "checkmark.seal")
            }
            NavigationLink(destination: ConfigurationView()) {
                Label("签名选项", systemImage: "signature")
            }
            NavigationLink(destination: ArchiveView()) {
                Label("归档与压缩", systemImage: "archivebox")
            }
            NavigationLink(destination: InstallationView()) {
                Label("安装", systemImage: "arrow.down.circle")
            }
        } footer: {
            Text("安装方式、压缩,自定义修改。")
        }
    }
    
    private var resetSection: some View {
        Section {
            NavigationLink(destination: ResetView()) {
                Label("重置", systemImage: "trash")
            }
        } footer: {
            Text("重置应用的源、证书、应用程序和设置。")
        }
    }

    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            Button("提交反馈", systemImage: "safari") {
                if let url = URL(string: "\(_githubUrl)/issues") {
                    UIApplication.shared.open(url)
                }
            }
            Button("👉看看源代码", systemImage: "safari") {
                if let url = URL(string: _githubUrl) {
                    UIApplication.shared.open(url)
                }
            }
        } footer: {
            Text("有任何问题，或建议，请随时提交。")
        }
    }
}
