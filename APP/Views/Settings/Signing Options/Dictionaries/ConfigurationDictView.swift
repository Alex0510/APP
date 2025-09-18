//
//  SigningOptionsDictView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI

// MARK: - View
struct ConfigurationDictView: View {
	@State private var _isAddingPresenting = false
	
	var title: String
	@Binding var dataDict: [String: String]
	
	// MARK: Body
	var body: some View {
		List {
			ForEach(dataDict.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
				Section(key) {
					Text(value).swipeActions(edge: .trailing) {
						_actions(key: key)
					}
				}
			}
		}
		.navigationTitle(title)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_isAddingPresenting = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			ConfigurationDictAddView(dataDict: $dataDict)
		}
	}
}

// MARK: - Extension: View
extension ConfigurationDictView {
	@ViewBuilder
	private func _actions(key: String) -> some View {
		Button(role: .destructive) {
			dataDict.removeValue(forKey: key)
		} label: {
			Label("删除", systemImage: "trash")
		}
	}
}
