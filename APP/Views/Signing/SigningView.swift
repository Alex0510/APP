//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews
import CoreData

// Protocol for signing views with additional flags
protocol SigningWithFlagsView {
	var signAndInstall: Bool { get }
}

// MARK: - View
struct SigningView: View, SigningWithFlagsView {
	@Environment(\.dismiss) var dismiss
	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
	// For Sign & Install feature
	var signAndInstall: Bool = false
	
	// MARK: Fetch
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
	
	init(app: AppInfoPresentable, signAndInstall: Bool = false) {
		self.app = app
		self.signAndInstall = signAndInstall
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
    var body: some View {
		NBNavigationView(app.name ?? .localized("未知"), displayMode: .inline) {
			Form {
				_customizationOptions(for: app)
				_cert()
				_customizationProperties(for: app)
			}
			.safeAreaInset(edge: .bottom) {
				Button() {
					_start()
				} label: {
					NBSheetButton(title: .localized("开始签名"))
				}
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				
				NBToolbarButton(
					.localized("重置"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { _, newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
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
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("自定义")) {
			Menu {
				Button(.localized("选择替代图标")) { _isAltPickerPresenting = true }
				Button(.localized("从文件选择")) { _isFilePickerPresenting = true }
				Button(.localized("从相册选择")) { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle(size: 55)
				} else {
					FRAppIconView(app: app, size: 55)
				}
			}
			
			_infoCell(.localized("名称"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("名称"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("标识符"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("标识符"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("版本"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("版本"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("签名")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("高级")) {
			DisclosureGroup(.localized("修改")) {
				NavigationLink(.localized("现有动态库")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(String.localized("框架和插件")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink(String.localized("权限")) {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				#endif
				NavigationLink(String.localized("插件")) {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink(String.localized("属性")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle(.localized("属性"))
			}
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("未知"))
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard _selectedCert() != nil || _temporaryOptions.doAdhocSigning || _temporaryOptions.onlyModify else {
			UIAlertController.showAlertWithOk(
				title: .localized("无证书"),
				message: .localized("请前往设置并导入有效证书"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true
		
		// Save the identifiers for later reference (use modified ones if available)
		let originalUUID = app.uuid
		let finalIdentifier = _temporaryOptions.appIdentifier ?? app.identifier
		let finalName = _temporaryOptions.appName ?? app.name
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { [self] error in
			if let error {
				let ok = UIAlertAction(title: .localized("关闭"), style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: .localized("签名"),
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				// Remove app after signed option thing
				if _temporaryOptions.removeApp && !app.isSigned {
					Storage.shared.deleteApp(for: app)
				}
				// Check if we need to install the app after signing
				if signAndInstall {
					// Find the signed app that matches our signed app
					let context = Storage.shared.context
					
					// Try to find by UUID first (most reliable if it's preserved)
					var signedApp: Signed? = nil
					
					if let uuid = originalUUID {
						let fetchRequest = NSFetchRequest<Signed>(entityName: "Signed")
						fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
						signedApp = try? context.fetch(fetchRequest).first
					}
					
					// If UUID search failed, try by the final (modified) app identifier and name
					if signedApp == nil, let identifier = finalIdentifier, let name = finalName {
						let fetchRequest = NSFetchRequest<Signed>(entityName: "Signed")
						fetchRequest.predicate = NSPredicate(format: "identifier == %@ AND name == %@", identifier, name)
						fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
						signedApp = try? context.fetch(fetchRequest).first
					}
					
					// As a last resort, just get the most recently signed app
					if signedApp == nil {
						let fetchRequest = NSFetchRequest<Signed>(entityName: "Signed")
						fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
						fetchRequest.fetchLimit = 1
						signedApp = try? context.fetch(fetchRequest).first
					}
					
					// If we found a signed app, show the installation dialog
					if let signedApp = signedApp {
						let installApp = AnyApp(base: signedApp)
						
						// Use a slight delay to ensure the UI has time to update
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
							NotificationCenter.default.post(
								name: NSNotification.Name("feather.installApp"),
								object: installApp
							)
						}
					}
				}
				dismiss()
			}
		}
	}
}
