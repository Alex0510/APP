//
//  SigningOptionsSharedView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningOptionsView: View {
    @Binding var options: Options
    var temporaryOptions: Options?
    
    // MARK: Body
    var body: some View {
        if (temporaryOptions == nil) {
            NBSection(.localized("保护")) {
                _toggle(.localized("PPQ保护"),
                        systemImage: "shield.fill",
                        isOn: $options.ppqProtection,
                        temporaryValue: temporaryOptions?.ppqProtection
                )
                // TODO: add dynamic protect (itunes api)
//                _toggle("Dynamic Protection",
//                        systemImage: "shield.lefthalf.filled",
//                        isOn: $options.dynamicProtection,
//                        temporaryValue: temporaryOptions?.dynamicProtection
//                )
//                    .disabled(!options.ppqProtection)
            } footer: {
                Text(.localized("启用任何保护功能都会在您签名的应用程序的包标识符后附加一个随机字符串，这是为了确保您的Apple ID不会被Apple标记。但是，当使用签名服务时，您可以忽略此功能。"))
            }
            Section {
                _toggle(.localized("签名后删除应用"),
                        systemImage: "trash",
                        isOn: $options.removeApp,
                        temporaryValue: temporaryOptions?.removeApp
                )
            } footer: {
                Text(.localized("这将在签名后删除应用（下载的应用）"))
            }
        } else {
            NBSection(.localized("通用")) {
                _picker(.localized("外观"),
                        systemImage: "paintpalette",
                        selection: $options.appAppearance,
                        values: Options.appAppearanceValues,
                        id: \.description
                )
                
                _picker(.localized("最低要求"),
                        systemImage: "ruler",
                        selection: $options.minimumAppRequirement,
                        values: Options.appMinimumAppRequirementValues,
                        id: \.description
                )
            }
            Section {
                _toggle(.localized("签名后删除应用"),
                        systemImage: "trash",
                        isOn: $options.removeApp,
                        temporaryValue: temporaryOptions?.removeApp
                )
                _toggle(.localized("仅修改（不签名）"),
                        systemImage: "pencil.slash",
                        isOn: $options.onlyModify,
                        temporaryValue: temporaryOptions?.onlyModify
                )
            }
        }
        
        NBSection(.localized("应用功能")) {
            _toggle(.localized("文件共享"),
                    systemImage: "folder.badge.person.crop",
                    isOn: $options.fileSharing,
                    temporaryValue: temporaryOptions?.fileSharing
            )
            
            _toggle(.localized("iTunes文件共享"),
                    systemImage: "music.note.list",
                    isOn: $options.itunesFileSharing,
                    temporaryValue: temporaryOptions?.itunesFileSharing
            )
            
            _toggle("ProMotion",
                    systemImage: "speedometer",
                    isOn: $options.proMotion,
                    temporaryValue: temporaryOptions?.proMotion
            )
            
            _toggle("GameMode",
                    systemImage: "gamecontroller",
                    isOn: $options.gameMode,
                    temporaryValue: temporaryOptions?.gameMode
            )
            
            _toggle(.localized("iPad全屏"),
                    systemImage: "ipad.landscape",
                    isOn: $options.ipadFullscreen,
                    temporaryValue: temporaryOptions?.ipadFullscreen
            )
        } footer: {
            Text(.localized("这些选项将改变应用的行为"))
        }
        
        NBSection(.localized("移除")) {
            _toggle(.localized("删除支持设备限制"),
                    systemImage: "iphone.slash",
                    isOn: $options.removeSupportedDevices,
                    temporaryValue: temporaryOptions?.removeSupportedDevices
            )
            
            _toggle(.localized("删除URL方案"),
                    systemImage: "ellipsis.curlybraces",
                    isOn: $options.removeURLScheme,
                    temporaryValue: temporaryOptions?.removeURLScheme
            )
            
            _toggle(.localized("移除配置文件"),
                    systemImage: "doc.badge.gearshape",
                    isOn: $options.removeProvisioning,
                    temporaryValue: temporaryOptions?.removeProvisioning
            )
            
            _toggle(.localized("移除Watch占位符"),
                    systemImage: "applewatch.slash",
                    isOn: $options.removeWatchPlaceholder,
                    temporaryValue: temporaryOptions?.removeWatchPlaceholder
            )
            
            _toggle(.localized("删除手表应用"),
                    systemImage: "applewatch.slash",
                    isOn: $options.removeWatchApp,
                    temporaryValue: temporaryOptions?.removeWatchApp
            )
            
            _toggle(.localized("删除扩展"),
                    systemImage: "puzzlepiece.extension",
                    isOn: $options.removeExtensions,
                    temporaryValue: temporaryOptions?.removeExtensions
            )
            
            _toggle(.localized("删除插件"),
                    systemImage: "plug",
                    isOn: $options.removePlugIns,
                    temporaryValue: temporaryOptions?.removePlugIns
            )
        } footer: {
            Text(.localized("这些选项将移除未签名IPA中的内容"))
        }
        
        Section {
            _toggle(.localized("强制本地化"),
                    systemImage: "character.bubble",
                    isOn: $options.changeLanguageFilesForCustomDisplayName,
                    temporaryValue: temporaryOptions?.changeLanguageFilesForCustomDisplayName
            )
        } footer: {
            Text(.localized("这将强制应用使用本地化"))
        }
        
        NBSection(.localized("高级")) {
            _toggle(.localized("临时签名"),
                    systemImage: "signature",
                    isOn: $options.doAdhocSigning,
                    temporaryValue: temporaryOptions?.doAdhocSigning
            )
        } footer: {
            Text(.localized("仅在您拥有临时证书时使用此功能"))
        }
    }
    
    @ViewBuilder
    private func _picker<SelectionValue, T>(
        _ title: String,
        systemImage: String,
        selection: Binding<SelectionValue>,
        values: [T],
        id: KeyPath<T, SelectionValue>
    ) -> some View where SelectionValue: Hashable {
        Picker(selection: selection) {
            ForEach(values, id: id) { value in
                Text(String(describing: value))
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
    
    @ViewBuilder
    private func _toggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        temporaryValue: Bool? = nil
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                if let tempValue = temporaryValue, tempValue != isOn.wrappedValue {
                    Text(title)
                } else {
                    Text(title)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
