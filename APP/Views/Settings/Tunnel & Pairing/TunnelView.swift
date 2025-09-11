//
//  SettingsTunnelView.swift
//  Feather (idevice)
//
//  Created by samara on 29.04.2025.
//

#if IDEVICE
import SwiftUI
import NimbleViews

// MARK: - View
struct TunnelView: View {
	@State private var _isImportingPairingPresenting = false
	
	@State var doesHavePairingFile = false
	
	// MARK: Body
    var body: some View {
		NBList(.localized("VPN和配对")) {
			Section {
				_tunnelInfo()
				TunnelHeaderView()
			} footer: {
				if doesHavePairingFile {
					Text(.localized("已经获得了配对文件！"))
				} else {
					Text(.localized("未找到配对文件，请导入。"))
				}
			}
			
			Section {
				Button(.localized("导入配对文件"), systemImage: "square.and.arrow.down") {
					_isImportingPairingPresenting = true
				}
				Button(.localized("重启心跳"), systemImage: "arrow.counterclockwise") {
					HeartbeatManager.shared.start(true)
					
					DispatchQueue.global(qos: .userInitiated).async {
						if !HeartbeatManager.shared.checkSocketConnection().isConnected {
							DispatchQueue.main.async {
								UIAlertController.showAlertWithOk(
									title: .localized("套接字"),
										message: .localized("无法连接到TCP。请确保已启用环回VPN并且您处于WiFi或飞行模式。")
								)
							}
						}
					}
				}
			}
			
			NBSection(.localized("帮助")) {
				Button(.localized("配对文件指南"), systemImage: "questionmark.circle") {
					UIApplication.open("https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md")
				}
				Button(.localized("下载StosVPN"), systemImage: "arrow.down.app") {
					UIApplication.open("https://apps.apple.com/us/app/stosvpn/id6744003051")
				}
			}
		}
		.sheet(isPresented: $_isImportingPairingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList, .plist, .mobiledevicepairing],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					FR.movePairing(selectedFileURL)
					doesHavePairingFile = true
				}
			)
		}
		.onAppear {
			if FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile()) {
				doesHavePairingFile = true
			} else {
				doesHavePairingFile = false
			}
		}
    }
	
	@ViewBuilder
	private func _tunnelInfo() -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("心跳"))
					.font(.headline)
				Text(.localized("心跳在后台激活，当应用重新打开或提示时会重启。如果下面的状态在跳动，说明它是健康的。"))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
	}
}
#endif
