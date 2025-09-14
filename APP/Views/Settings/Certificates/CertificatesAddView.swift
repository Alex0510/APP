
import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	
	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}
	
	var body: some View {
		NBNavigationView(.localized("新证书"), displayMode: .inline) {
			Form {
				NBSection(.localized("文件")) {
					_importButton(.localized("导入证书文件"), file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("导入配置文件"), file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("密码")) {
					SecureField(.localized("输入密码"), text: $_p12Password)
				} footer: {
					Text(.localized("输入与私钥关联的密码。如果没有密码要求，请留空。"))
				}
				
				Section {
					TextField(.localized("昵称（可选）"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("保存"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
		}
	}
}

extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor(file == nil ? .accentColor : .disabled())
		.disabled(file != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil)
	}
}

extension CertificatesAddView {
	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("密码错误"),
				message: .localized("请检查密码并重试。")
			)
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { _ in
			dismiss()
		}
	}
}

