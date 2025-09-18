//
//  ConfigurationDictAddView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI

// MARK: - View
struct ConfigurationDictAddView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var _newKey = ""
	@State private var _newValue = ""
	@State private var _showOverrideAlert = false
	
	var saveButtonDisabled: Bool {
		_newKey.isEmpty || _newValue.isEmpty
	}
	
	@Binding var dataDict: [String: String]
	
	// MARK: Body
    var body: some View {
		List {
			Section {
				TextField("值", text: $_newKey)
				TextField("替换值", text: $_newValue)
			}
			.autocapitalization(.none)
		}
		.navigationTitle("新建")
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button {
					dataDict[_newKey] = _newValue
					OptionsManager.shared.saveOptions()
					dismiss()
				} label: {
					Text("保存")
				}
				.disabled(saveButtonDisabled)
			}
		}
    }
}
