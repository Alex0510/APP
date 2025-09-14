//
//  ConfigurationDictAddView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

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
		NBList(.localized("新建")) {
			Section {
				TextField(.localized("值"), text: $_newKey)
				TextField(.localized("替换值"), text: $_newValue)
			}
			.autocapitalization(.none)
		}
		.toolbar {
			NBToolbarButton(
				.localized("保存"),
				style: .text,
				placement: .confirmationAction,
				isDisabled: saveButtonDisabled
			) {
				dataDict[_newKey] = _newValue
				OptionsManager.shared.saveOptions()
				dismiss()
			}
		}
    }
}
