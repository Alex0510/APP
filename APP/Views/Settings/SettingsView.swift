//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SettingsView: View {
	// MARK: Body
    var body: some View {
		NBNavigationView("设置") {
			Form {
				Section {
					NavigationLink(destination: AppearanceView()) {
                        Label(.localized("外观"), systemImage: "paintbrush")
                    }
				}
				
				NBSection(.localized("功能")) {
					NavigationLink(destination: CertificatesView()) {
                        Label(.localized("证书"), systemImage: "signature")
                    }
					NavigationLink(destination: ConfigurationView()) {
                        Label(.localized("签名选项"), systemImage: "gear")
                    }
					NavigationLink(destination: ArchiveView()) {
                        Label(.localized("归档和提取"), systemImage: "archivebox")
                    }
					#if SERVER
					NavigationLink(destination: ServerView()) {
                        Label(.localized("服务器和SSL"), systemImage: "server.rack")
                    }
					#elseif IDEVICE
					NavigationLink(destination: TunnelView()) {
                        Label(.localized("VPN和配对"), systemImage: "network")
                    }
					#endif
				}
				
				_directories()
            }
        }
    }
}

// MARK: - View extension
extension SettingsView {	
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("其他")) {
			Button(.localized("打开文档"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("打开归档"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("清除截图"), systemImage: "trash") {
				_clearScreenshots()
			}
			.foregroundColor(.red)
		} footer: {
			Text(.localized("这里是一些快捷链接，用于快速访问应用的文档目录和归档目录。"))
		}
	}
	
	private func _clearScreenshots() {
		let screenshotsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Screenshots")
		
		guard let screenshotsURL = screenshotsPath, FileManager.default.fileExists(atPath: screenshotsURL.path) else {
			return
		}
		
		do {
			let contents = try FileManager.default.contentsOfDirectory(at: screenshotsURL, includingPropertiesForKeys: nil)
			for fileURL in contents {
				try FileManager.default.removeItem(at: fileURL)
			}
		} catch {
			print("Error clearing screenshots: \(error.localizedDescription)")
		}
	}
}
