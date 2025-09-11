//
//  CertificatesInfoView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesInfoView: View {
	@Environment(\.dismiss) var dismiss
	@State var data: Certificate?
	
	var cert: CertificatePair
	
	// MARK: Body
    var body: some View {
		NBNavigationView(cert.nickname ?? "", displayMode: .inline) {
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
					Button(.localized("导出证书"), systemImage: "square.and.arrow.up") {
						exportCertificate(cert)
					}
				}
				
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
		}
    }
}

// MARK: - Extension: View
extension CertificatesInfoView {
	@ViewBuilder
	private func _infoSection(data: Certificate) -> some View {
		NBSection(.localized("信息")) {
			_info(.localized("名称"), description: data.Name)
			_info(.localized("应用ID名称"), description: data.AppIDName)
			_info(.localized("团队名称"), description: data.TeamName)
		}
		
		Section {
			_info(.localized("过期时间"), description: data.ExpirationDate.expirationInfo().formatted)
				.foregroundStyle(data.ExpirationDate.expirationInfo().color)
            
            _info(.localized("已撤销"), description: cert.revoked ? "是" : "否")
            
			if let ppq = data.PPQCheck {
				_info("PPQCheck", description: ppq ? "Yes" : "No")
			}
		}
	}
	
	@ViewBuilder
	private func _entitlementsSection(data: Certificate) -> some View {
		if let entitlements = data.Entitlements {
			Section {
				NavigationLink(.localized("查看权限")) {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _miscSection(data: Certificate) -> some View {
		NBSection(.localized("其他")) {
			_disclosure(.localized("平台"), keys: data.Platform)
			
			if let all = data.ProvisionsAllDevices {
				_info(.localized("配置所有设备"), description: all.description)
			}
			
			if let devices = data.ProvisionedDevices {
				_disclosure(.localized("已配置设备"), keys: devices)
			}
			
			_disclosure(.localized("团队标识符"), keys: data.TeamIdentifier)
			
			if let prefix = data.ApplicationIdentifierPrefix{
				_disclosure(.localized("标识符前缀"), keys: prefix)
			}
		}
	}
	
	@ViewBuilder
	private func _info(_ title: String, description: String) -> some View {
		LabeledContent(title) {
			Text(description)
		}
	}
	
	@ViewBuilder
	private func _disclosure(_ title: String, keys: [String]) -> some View {
		DisclosureGroup(title) {
			ForEach(keys, id: \.self) { key in
				Text(key)
					.foregroundStyle(.secondary)
			}
		}
	}
}

// MARK: - Extension: Certificate Export
extension CertificatesInfoView {
	private func exportCertificate(_ cert: CertificatePair) {
		guard let uuid = cert.uuid else { return }
		
		guard let certData = Storage.shared.getCertificateDataForExport(from: cert),
			  let jsonData = try? JSONSerialization.data(withJSONObject: certData) else {
			return
		}
		
		guard let finalData = CertificateEncryption.encryptKsignData(jsonData) else {
			print("Error encrypting certificate data")
			return
		}
		
		let sanitizedName = (cert.nickname ?? "Certificate")
			.replacingOccurrences(of: "/", with: "-")
			.replacingOccurrences(of: ":", with: "-")
			.replacingOccurrences(of: "\\", with: "-")
		
		let tempDir = FileManager.default.temporaryDirectory
		let fileName = "\(sanitizedName).ksign"
		let fileURL = tempDir.appendingPathComponent(fileName)
		
		do {
			try finalData.write(to: fileURL)
			
			let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
			
			if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			   let rootViewController = windowScene.windows.first?.rootViewController {
				
				if let presentedVC = rootViewController.presentedViewController {
					presentedVC.present(activityVC, animated: true)
				} else {
					rootViewController.present(activityVC, animated: true)
				}
			}
		} catch {
			print("Error exporting certificate: \(error)")
		}
	}
	

}
