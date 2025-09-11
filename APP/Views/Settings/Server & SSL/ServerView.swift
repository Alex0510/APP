//
//  ServerView.swift
//  Feather
//
//  Created by samara on 6.05.2025.
//

import SwiftUI
import NimbleJSON
import NimbleViews

struct ServerView: View {
	@AppStorage("Feather.ipFix") private var _ipFix: Bool = false
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 0
	
	private let _serverMethods: [String] = [
		.localized("完全本地"), 
		.localized("半本地")
	]
	
	private let _dataService = NBFetchService()
	private let _serverPackUrl = "https://backloop.dev/pack.json"
	
	var body: some View {
		NBList(.localized("服务器和SSL")) {
			Section {
				Picker(.localized("安装类型"), systemImage: "server.rack", selection: $_serverMethod) {
					ForEach(_serverMethods.indices, id: \.self) { index in
						Text(_serverMethods[index]).tag(index)
					}
				}
				Toggle(.localized("仅使用本地主机地址"), systemImage: "lifepreserver", isOn: $_ipFix)
					.disabled(_serverMethod != 1)
			}
			
			Section {
				Button(.localized("更新SSL证书"), systemImage: "arrow.down.doc") {
					#if SERVER
					FR.downloadSSLCertificates(from: _serverPackUrl) { success in
						if !success {
							DispatchQueue.main.async {
								UIAlertController.showAlertWithOk(
									title: .localized("SSL证书"),
									message: .localized("下载失败，请检查网络连接后重试。")
								)
							}
						}
					}
					#else
					// Server functionality not available in this build
					DispatchQueue.main.async {
						UIAlertController.showAlertWithOk(
							title: .localized("SSL证书"),
							message: .localized("此版本不支持服务器功能。")
						)
					}
					#endif
				}
			}
		}
		.onChange(of: _serverMethod) { _, _ in
			UIAlertController.showAlertWithRestart(
				title: .localized("需要重启"),
				message: .localized("这些更改需要重启应用")
			)
		}
	}
}
