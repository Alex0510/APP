
import SwiftUI
import UniformTypeIdentifiers


struct FileImporterRepresentableView: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onResult: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onResult: (Result<URL, Error>) -> Void
        
        init(onResult: @escaping (Result<URL, Error>) -> Void) {
            self.onResult = onResult
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onResult(.failure(NSError(domain: "FileImporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])))
                return
            }
            onResult(.success(url))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onResult(.failure(NSError(domain: "FileImporter", code: -2, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])))
        }
    }
}

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
		NavigationView {
			Form {
				Section("文件") {
					_importButton("导入证书文件", file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton("导入配置文件", file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				Section {
					SecureField("输入密码", text: $_p12Password)
				} header: {
					Text("密码")
				} footer: {
					Text("输入与私钥关联的密码。如果没有密码要求，请留空。")
				}
				
				Section {
					TextField("昵称（可选）", text: $_certificateName)
				}
			}
			.navigationTitle("新证书")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("取消") {
						dismiss()
					}
				}
				
				ToolbarItem(placement: .confirmationAction) {
					Button {
						_saveCertificate()
					} label: {
						Text("保存")
					}
					.disabled(saveButtonDisabled)
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onResult: { result in
						switch result {
						case .success(let url):
							self._p12URL = url
						case .failure(let error):
							print("Error selecting file: \(error)")
						}
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onResult: { result in
						switch result {
						case .success(let url):
							self._provisionURL = url
						case .failure(let error):
							print("Error selecting file: \(error)")
						}
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
		HStack {
			Button(title) {
				action()
			}
			.foregroundColor(.accentColor)
			
			Spacer()
			
			if let file = file {
				Text(file.lastPathComponent)
					.font(.caption)
					.foregroundColor(.secondary)
					.lineLimit(1)
			}
		}
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
				title: "密码错误",
				message: "请检查密码并重试。"
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

