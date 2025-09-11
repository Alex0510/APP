//
//  LibraryAppIconView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
	@AppStorage("Feather.libraryCellAppearance") private var _libraryCellAppearance: Int = 0

	var certInfo: Date.ExpirationInfo? {
		Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
	}
	
	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var isEditMode: Bool
	@Binding var selectedApps: Set<String>
	@State private var _showActionSheet = false
	@State private var _showDylibsView = false
	
	private var _isSelected: Bool {
		selectedApps.contains(app.uuid ?? "")
	}
	
	// MARK: Body
	var body: some View {
		HStack(spacing: 9) {
			if isEditMode {
				Button {
					_toggleSelection()
				} label: {
					Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
						.foregroundColor(_isSelected ? .accentColor : .secondary)
						.font(.title2)
				}
				.buttonStyle(.borderless)
			}
			
			FRAppIconView(app: app, size: 57)
			
			NBTitleWithSubtitleView(
				title: app.name ?? .localized("未知"),
				subtitle: _desc,
				linelimit: 0
			)
			
			Spacer()
			
			if !isEditMode {
				if app.isSigned, let certInfo = certInfo {
					HStack(spacing: 4) {
						Image(systemName: "clock")
							.font(.system(size: 11))
	                    Text(certInfo.formatted)
							.font(.system(size: 12))
							.fontWeight(.semibold)
					}
					.foregroundColor(.white)
					.padding(.horizontal, 10)
					.padding(.vertical, 5)
					.background(certInfo.color)
					.clipShape(Capsule())
					.padding(.trailing, 4)
				}
				
				Image(systemName: "chevron.right")
					.foregroundColor(.secondary)
					.font(.footnote)
			}
		}
		.scaleEffect(_isSelected ? 0.98 : 1.0)
		.contentShape(Rectangle())
		.onTapGesture {
			if isEditMode {
				_toggleSelection()
			} else {
				_showActionSheet = true
			}
		}
		.confirmationDialog(
			app.name ?? .localized("未知"),
			isPresented: $_showActionSheet,
			titleVisibility: .visible
		) {
			if !isEditMode {
				_actionSheetButtons(for: app)
			}
		}
		.swipeActions {
			if !isEditMode {
				_actions(for: app)
			}
		}
		.contextMenu {
			if !isEditMode {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				_actions(for: app)
			}
		}
		.sheet(isPresented: $_showDylibsView) {
			if let appDir = Storage.shared.getAppDirectory(for: app) {
				DylibsView(appPath: appDir, appName: app.name ?? .localized("框架和动态库"))
			}
		}
	}
	
	private var _desc: String {
		if
			let version = app.version,
			let id = app.identifier
		{
			return "\(version) • \(id)"
		} else {
			return .localized("未知")
		}
	}
	
	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		
		let impactFeedback = UIImpactFeedbackGenerator(style: .light)
		impactFeedback.impactOccurred()
		
		withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
			if _isSelected {
				selectedApps.remove(uuid)
			} else {
				selectedApps.insert(uuid)
			}
		}
	}
}

// MARK: - Extension: View
extension LibraryCellView {
	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("删除"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("获取信息"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}
	
	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if app.isSigned {
			if let id = app.identifier {
				Button(.localized("打开"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("安装"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("重新签名"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			Button(.localized("导出"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("安装"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
		}
	}
	
	@ViewBuilder
	private func _actionSheetButtons(for app: AppInfoPresentable) -> some View {
		if app.isSigned {
			Button(.localized("安装")) {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			
			if let id = app.identifier {
				Button(.localized("打开")) {
					UIApplication.openApp(with: id)
				}
			}
			
			Button(.localized("重新签名")) {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			
			Button(.localized("导出")) {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("签名并安装")) {
				selectedSigningAppPresenting = AnyApp(base: app, signAndInstall: true)
			}
			
			Button(.localized("签名")) {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
			
			Button(.localized("导出")) {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		}
		
		Button(.localized("显示动态库")) {
			_showDylibsView = true
		}
		
		Button(.localized("获取信息")) {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
		
		Button(.localized("删除"), role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	@ViewBuilder
	private func _buttonActions(for app: AppInfoPresentable) -> some View {
		Group {
			if app.isSigned {
				Button {
					selectedInstallAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("安装"),
						showOverlay: _libraryCellAppearance == 0,
						expiration: certInfo
					)
				}
			} else {
				Button {
					selectedSigningAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("签名"),
						showOverlay: true,
						expiration: nil
					)
				}
			}
		}
		.buttonStyle(.borderless)
	}
}
