//
//  SigningOptionsView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI

// MARK: - View
struct ConfigurationView: View {
	@StateObject private var _optionsManager = OptionsManager.shared
	@State var isRandomAlertPresenting = false
	@State var randomString = ""
	
	// MARK: Body
    var body: some View {
		List {
            Section {
                NavigationLink(destination: ConfigurationDictView(
						title: "显示名称",
                        dataDict: $_optionsManager.options.displayNames
                    )
                ) {
					Label("显示名称", systemImage: "character.cursor.ibeam")
                }
                NavigationLink(destination: ConfigurationDictView(
						title: "标识符",
                        dataDict: $_optionsManager.options.identifiers
                    )
                ) {
					Label("标识符", systemImage: "person.text.rectangle")
                }
            }footer: {
				Text("设置规则，在签名时自动替换Bundle ID/显示名称。")
            }
            SigningOptionsView(options: $_optionsManager.options)
		}
		.navigationTitle("签名选项")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					_randomMenuItem()
				} label: {
					Image(systemName: "character.textbox")
				}
			}
		}
		.alert(_optionsManager.options.ppqString, isPresented: $isRandomAlertPresenting) {
			_randomMenuAlert()
		}
		.onChange(of: _optionsManager.options) { _ in
			_optionsManager.saveOptions()
		}
    }
}

// MARK: - Extension: View
extension ConfigurationView {
	@ViewBuilder
	private func _randomMenuItem() -> some View {
		Section(_optionsManager.options.ppqString) {
			Button("更改") {
				isRandomAlertPresenting = true
			}
			Button("复制") {
				UIPasteboard.general.string = _optionsManager.options.ppqString
			}
		}
	}
	
	@ViewBuilder
	private func _randomMenuAlert() -> some View {
			TextField("字符串", text: $randomString)
			Button("保存") {
			if !randomString.isEmpty {
				_optionsManager.options.ppqString = randomString
			}
		}
		
			Button("取消", role: .cancel) {}
	}
}
