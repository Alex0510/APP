
import SwiftUI
import ZsignSwift
// 使用内部扩展代替NimbleExtensions

struct CertificatesInfoView: View {
	@Environment(\.dismiss) var dismiss
	@State var data: Certificate?
	
	var cert: CertificatePair
	
    var body: some View {
		NavigationView {
			Form {
				Section {} header: {
					Image("Cert")
						.resizable()
						.scaledToFit()
						.frame(width: 107, height: 107)
						.frame(maxWidth: .infinity, alignment: .center)
				}
				
				if let data {
					_infoSection(data: data)
					_entitlementsSection(data: data)
					_miscSection(data: data)
				}
				
				Section {
					Button("在文件中打开", systemImage: "folder") {
						if let uuidDir = Storage.shared.getUuidDirectory(for: cert) {
							let urlString = uuidDir.absoluteString
							if urlString.hasPrefix("file://") {
								let newURLString = "shareddocuments://" + urlString.dropFirst("file://".count)
								if let sharedURL = URL(string: newURLString) {
									UIApplication.shared.open(sharedURL)
								}
							}
						}
					}
				}
			}
			.navigationTitle(cert.nickname ?? "")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("取消") {
						dismiss()
					}
				}
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
		}
    }
}

extension CertificatesInfoView {
	@ViewBuilder
	private func _infoSection(data: Certificate) -> some View {
		Section {
			_info("名称", description: data.Name)
			_info("应用ID名称", description: data.AppIDName)
			_info("团队名称", description: data.TeamName)
		} header: {
			Text("信息")
		}
		
		Section {
			_info("过期时间", description: data.ExpirationDate.expirationInfo().formatted)
				.foregroundStyle(data.ExpirationDate.expirationInfo().color)
			
			_info("已撤销", description: cert.revoked ? "✓" : "✗")
			
			if let ppq = data.PPQCheck {
				_info("PPQ检查", description: ppq ? "✓" : "✗")
			}
		}
	}
	
	@ViewBuilder
	private func _entitlementsSection(data: Certificate) -> some View {
		if let entitlements = data.Entitlements {
			Section {
				NavigationLink("查看权限", destination: CertificatesInfoEntitlementView(entitlements: entitlements))
			}
		}
	}
	
	@ViewBuilder
	private func _miscSection(data: Certificate) -> some View {
		Section {
			_disclosure("平台", keys: data.Platform)
			
			if let all = data.ProvisionsAllDevices {
				_info("配置所有设备", description: all.description)
			}
			
			if let devices = data.ProvisionedDevices {
				_disclosure("已配置设备", keys: devices)
			}
			
			_disclosure("团队标识符", keys: data.TeamIdentifier)
			
			if let prefix = data.ApplicationIdentifierPrefix{
				_disclosure("标识符前缀", keys: prefix)
			}
		} header: {
			Text("其他")
		}
	}
	
	@ViewBuilder
	private func _info(_ title: String, description: String) -> some View {
		HStack {
			Text(title)
			Spacer()
			Text(description)
				.foregroundColor(.secondary)
		}
		.copyableText(description)
	}
	
	@ViewBuilder
	private func _disclosure(_ title: String, keys: [String]) -> some View {
		DisclosureGroup(title) {
			ForEach(keys, id: \.self) { key in
				Text(key)
					.foregroundStyle(.secondary)
					.copyableText(key)
			}
		}
	}
}
