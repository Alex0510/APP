//
//  SigningAppPropertiesView.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import SwiftUI

// MARK: - View
struct SigningPropertiesView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var text: String = ""
	
	var saveButtonDisabled: Bool {
		text == initialValue
	}
	
	var title: String
	var initialValue: String 
	@Binding var bindingValue: String?
	
	// MARK: Body
	var body: some View {
		List {
			TextField(initialValue, text: $text)
				.textInputAutocapitalization(.none)
		}
		.navigationTitle(title)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					if !saveButtonDisabled {
						bindingValue = text
						dismiss()
					}
				} label: {
					Text("保存")
				}
				.disabled(saveButtonDisabled)
			}
		}
		.onAppear {
			text = initialValue
		}
	}
}
