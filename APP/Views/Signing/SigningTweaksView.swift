//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		NBList(.localized("Tweaks")) {
			NBSection(.localized("Injection")) {
				SigningOptionsView.picker(
					.localized("Injection Path"),
					systemImage: "doc.badge.gearshape",
					selection: $options.injectPath,
					values: Options.InjectPath.allCases
				)
				SigningOptionsView.picker(
					.localized("Injection Folder"),
					systemImage: "folder.badge.gearshape",
					selection: $options.injectFolder,
					values: Options.InjectFolder.allCases
				)
			}
			
			NBSection(.localized("Tweaks")) {
				if !options.injectionFiles.isEmpty {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak)
					}
				} else {
					Text(verbatim: .localized("No files chosen."))
						.font(.footnote)
						.foregroundColor(.disabled())
				}
			}
		}
		.toolbar {
			NBToolbarButton(
				systemImage: "plus",
				style: .icon,
				placement: .topBarTrailing
			) {
				_isAddingPresenting = true
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.dylib, .deb],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					DispatchQueue.main.async { _isAddingPresenting = false }
					guard !urls.isEmpty else { return }
					let validUrls = urls.filter { ["dylib", "deb"].contains($0.pathExtension.lowercased()) }
					for url in validUrls {
						FileManager.default.moveAndStore(url, with: "FeatherTweak") { storedURL in
							DispatchQueue.main.async {
								if !options.injectionFiles.contains(storedURL) {
									options.injectionFiles.append(storedURL)
								}
							}
						}
					}
				}
			)
			.ignoresSafeArea()
		}
		.animation(.smooth, value: options.injectionFiles)
	}
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL) -> some View {
		Label(tweak.lastPathComponent, systemImage: "folder.fill")
			.lineLimit(2)
			.frame(maxWidth: .infinity, alignment: .leading)
			.swipeActions(edge: .trailing, allowsFullSwipe: true) {
				_fileActions(tweak: tweak)
			}
			.contextMenu {
				_fileActions(tweak: tweak)
			}
	}
	
	@ViewBuilder
	private func _fileActions(tweak: URL) -> some View {
		Button(role: .destructive) {
			FileManager.default.deleteStored(tweak) { url in
				if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
					options.injectionFiles.remove(at: index)
				}
			}
		} label: {
			Label(.localized("Delete"), systemImage: "trash")
		}
	}
}
