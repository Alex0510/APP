//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		List {
			Section {
				SigningOptionsView.picker(
					"Injection Path",
					systemImage: "doc.badge.gearshape",
					selection: $options.injectPath,
					values: Options.InjectPath.allCases
				)
				SigningOptionsView.picker(
					"Injection Folder",
					systemImage: "folder.badge.gearshape",
					selection: $options.injectFolder,
					values: Options.InjectFolder.allCases
				)
			} header: {
				Text("Injection")
			}
			
			Section {
				if !options.injectionFiles.isEmpty {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak)
					}
				} else {
					Text("No files chosen.")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			} header: {
				Text("Tweaks")
			}
		}
		.navigationTitle("Tweaks")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_isAddingPresenting = true
				} label: {
					Text("添加")
				}
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.dylib, .deb],
				onResult: { result in
					DispatchQueue.main.async { _isAddingPresenting = false }
					switch result {
					case .success(let url):
						guard ["dylib", "deb"].contains(url.pathExtension.lowercased()) else { return }
						FileManager.default.moveAndStore(url, with: "FeatherTweak") { storedURL in
							DispatchQueue.main.async {
								if !options.injectionFiles.contains(storedURL) {
									options.injectionFiles.append(storedURL)
								}
							}
						}
					case .failure(let error):
						print("Failed to import files: \(error)")
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
			Label("Delete", systemImage: "trash")
		}
	}
}
