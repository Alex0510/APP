//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss
	
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	
	#if SERVER
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 0
	@State private var _isWebviewPresenting = false
	@State private var installer: ServerInstaller?
	#endif

	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@State var isSharing: Bool

	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
		let viewModel = InstallerStatusViewModel()
		self._viewModel = StateObject(wrappedValue: viewModel)
	}
	
	// MARK: Body
	var body: some View {
		ZStack {
			InstallProgressView(app: app, viewModel: viewModel)
			_status()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(Color(UIColor.secondarySystemBackground))
		.cornerRadius(12)
		.padding()
		#if SERVER
		.sheet(isPresented: $_isWebviewPresenting) {
			if let installer = installer {
				SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
			}
		}
		.onReceive(viewModel.$status) { newStatus in
			#if DEBUG
			print(newStatus)
			#endif
			if case .ready = newStatus {
				if _serverMethod == 0 {
					if let installer = installer {
						UIApplication.shared.open(URL(string: installer.iTunesLink)!)
					}
				} else if _serverMethod == 1 {
					_isWebviewPresenting = true
				}
			}
			
			if case .sendingPayload = newStatus, _serverMethod == 1 {
				_isWebviewPresenting = false
			}
		}
		#endif
		.onAppear {
			#if SERVER
			Task {
				do {
					let serverInstaller = try await ServerInstaller(app: app, viewModel: viewModel)
					await MainActor.run {
						self.installer = serverInstaller
					}
				} catch {
					print("Failed to initialize ServerInstaller: \(error)")
				}
			}
			#endif
			_install()
		}
	}
	
	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.padding()
			.labelStyle(.titleAndIcon)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	private func _install() {
		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				if await !isSharing {
					#if SERVER
					await MainActor.run {
						if let installer = installer {
							installer.packageUrl = packageUrl
						}
						viewModel.status = .ready
					}
					#elseif IDEVICE
					let handler = await ConduitInstaller(viewModel: viewModel)
					try await handler.install(at: packageUrl)
					#endif
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					
					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch {
				await MainActor.run {
					UIAlertController.showAlertWithOk(
						title: .localized("安装"),
						message: error.localizedDescription,
						action: {
							#if IDEVICE
							HeartbeatManager.shared.start(true)
							#endif
							dismiss()
						}
					)
				}
			}
		}
	}
}
