import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

struct SettingsView: View {
    private let _githubUrl = "https://github.com/pxx917144686/APP"
    @State private var currentIcon = UIApplication.shared.alternateIconName
    
    var body: some View {
        NavigationStack {
            Form {
                
                _feedback()
                
                appearanceSection
                
                signingSection
                
                resetSection
            }
        }
    }
}

extension SettingsView {
    
    private var appearanceSection: some View {
        Section {
            NavigationLink(destination: AppearanceView()) {
                Label(.localized("外观"), systemImage: "paintbrush")
            }
            NavigationLink(destination: AppIconView(currentIcon: $currentIcon)) {
                Label(.localized("图标"), systemImage: "app.badge")
            }
        }
    }
    
    private var signingSection: some View {
        Section {
            NavigationLink(destination: CertificatesView()) {
                Label(.localized("证书"), systemImage: "checkmark.seal")
            }
            NavigationLink(destination: ConfigurationView()) {
                Label(.localized("签名选项"), systemImage: "signature")
            }
            NavigationLink(destination: ArchiveView()) {
                Label(.localized("归档与压缩"), systemImage: "archivebox")
            }
            NavigationLink(destination: InstallationView()) {
                Label(.localized("安装"), systemImage: "arrow.down.circle")
            }
        } footer: {
            Text(.localized("安装方式、压缩,自定义修改。"))
        }
    }
    
    private var resetSection: some View {
        Section {
            NavigationLink(destination: ResetView()) {
                Label(.localized("重置"), systemImage: "trash")
            }
        } footer: {
            Text(.localized("重置应用的源、证书、应用程序和设置。"))
        }
    }

    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            Button(.localized("提交反馈"), systemImage: "safari") {
                UIApplication.open("\(_githubUrl)/issues")
            }
            Button(.localized("👉看看源代码"), systemImage: "safari") {
                UIApplication.open(_githubUrl)
            }
        } footer: {
            Text(.localized("有任何问题，或建议，请随时提交。"))
        }
    }
}
