
import SwiftUI
import PhotosUI

struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: Any? = nil
	@State var appIcon: UIImage?
	
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable) {
		self.app = app
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
    var body: some View {
		NavigationView {
			mainContent
			.navigationTitle(app.name ?? "未知")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("取消") {
						dismiss()
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						_temporaryOptions = OptionsManager.shared.options
						appIcon = nil
					} label: {
						Text("重置")
					}
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onResult: { result in
						DispatchQueue.main.async { _isFilePickerPresenting = false }
						switch result {
						case .success(let selectedFileURL):
							DispatchQueue.main.async {
								if let imageData = try? Data(contentsOf: selectedFileURL),
								   let image = UIImage(data: imageData) {
									self.appIcon = image
								}
							}
						case .failure(let error):
							print("Failed to import image: \(error)")
						}
					}
				)
				.ignoresSafeArea()
			}
			// Photos picker removed for iOS 15 compatibility
			// .photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			// .onChange(of: _selectedPhoto) { newValue in
			//     guard let newValue else { return }
			//     
			//     Task {
			//         if let data = try? await newValue.loadTransferable(type: Data.self),
			//            let image = UIImage(data: data)?.resizeToSquare() {
			//             appIcon = image
			//         }
			//     }
			// }
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			// 同步“液态玻璃”总开关到临时选项，确保顶层设置生效
			_temporaryOptions.experiment_supportLiquidGlass = _optionsManager.options.experiment_supportLiquidGlass
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
		}
    }

    private var mainContent: some View {
        Form {
            _customizationOptions(for: app)
            _cert()
            _customizationProperties(for: app)
            
            Rectangle()
                .foregroundStyle(.clear)
                .frame(height: 30)
                .listRowBackground(EmptyView())
        }
        .overlay {
            VStack(spacing: 0) {
                Spacer()
                // NBVariableBlurView removed for iOS 15 compatibility
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 60 : 80)
                    .rotationEffect(Angle(degrees: 180))
                    .overlay {
                        Button {
                            _start()
                        } label: {
                            Text("开始签名")
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        .offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -20 : -40)
                    }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
                Section {
			Menu {
				Button("选择替代图标", systemImage: "app.dashed") { _isAltPickerPresenting = true }
				Button("从文件选择", systemImage: "folder") { _isFilePickerPresenting = true }
				Button("从照片选择", systemImage: "photo") { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle()
				} else {
					FRAppIconView(app: app, size: 56)
				}
			}
			
			_infoCell("名称", desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: "名称",
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell("标识符", desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: "标识符",
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell("版本", desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: "版本",
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		Section("签名") {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			} else {
				Text("无证书")
					.font(.footnote)
					.foregroundColor(.secondary)
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		Section {
			DisclosureGroup("修改") {
				NavigationLink("现有动态库") {
					SigningDylibView(
						app: app,
						options: Binding<Options?>(
							get: { _temporaryOptions },
							set: { _temporaryOptions = $0 ?? Options.defaultOptions }
						)
					)
				}
				
				NavigationLink("框架和插件") {
					SigningFrameworksView(
						app: app,
						options: Binding<Options?>(
							get: { _temporaryOptions },
							set: { _temporaryOptions = $0 ?? Options.defaultOptions }
						)
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink("权限" + " (测试版)") {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				#endif
				NavigationLink("调整") {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink("属性") {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle("属性")
			}
		} header: {
			Text("高级")
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			HStack {
				Text(title)
				Spacer()
				Text(desc ?? "未知")
					.foregroundColor(.secondary)
			}
		}
	}
}

extension SigningView {
	private func _start() {
		guard
			_selectedCert() != nil || _temporaryOptions.signingOption != .default
		else {
			UIAlertController.showAlertWithOk(
				title: "无证书",
				message: "请前往设置并导入有效证书",
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { error in
			if let error {
				let ok = UIAlertAction(title: "关闭", style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: "错误",
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				if
					_temporaryOptions.post_deleteAppAfterSigned,
					!app.isSigned
				{
					Storage.shared.deleteApp(for: app)
				}
				
				if _temporaryOptions.post_installAppAfterSigned {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
						NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
					}
				}
				dismiss()
			}
		}
	}
}

