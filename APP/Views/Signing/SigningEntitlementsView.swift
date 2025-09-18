//
//  SigningEntitlementsView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI

// MARK: - View
struct SigningEntitlementsView: View {
	@State private var _isAddingPresenting = false
	
	@Binding var bindingValue: URL?
	
	// MARK: Body
	var body: some View {
		List {
			if let ent = bindingValue {
				Text(ent.lastPathComponent)
					.swipeActions() {
						Button("Delete") {
							FileManager.default.deleteStored(ent) { _ in
								bindingValue = nil
							}
						}
					}
			} else {
				Button("Select entitlements file") {
					_isAddingPresenting = true
				}
			}
		}
		.navigationTitle("Entitlements")
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList, .entitlements],
				onResult: { result in
					DispatchQueue.main.async { _isAddingPresenting = false }
					switch result {
					case .success(let selectedFileURL):
						FileManager.default.moveAndStore(selectedFileURL, with: "FeatherEntitlement") { url in
							DispatchQueue.main.async { bindingValue = url }
						}
					case .failure(let error):
						print("Failed to import entitlements file: \(error)")
					}
				}
			)
			.ignoresSafeArea()
		}
	}
}
