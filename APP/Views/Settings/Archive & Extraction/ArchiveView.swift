//
//  ArchiveView.swift
//  Feather
//
//  Created by samara on 6.05.2025.
//

import SwiftUI
import ZipArchive
import NimbleViews

struct ArchiveView: View {
	@AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZipCompression.DefaultCompression.rawValue
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = true
	@AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false
	@AppStorage("Feather.extractionLibrary") private var _extractionLibrary: String = "Zip"
    
    var body: some View {
		NBList(.localized("归档和提取")) {
			Section {
				Picker(.localized("压缩级别"), systemImage: "archivebox", selection: $_compressionLevel) {
					ForEach(ZipCompression.allCases, id: \.rawValue) { level in
						Text(level.label).tag(level)
					}
				}
			}
			
			Section {
				Toggle(.localized("导出时显示分享表"), systemImage: "square.and.arrow.up", isOn: $_useShareSheet)
			} footer: {
				Text(.localized("切换显示分享表将在导出到文件后显示分享表。"))
			}
            
            Section {
                Toggle(.localized("使用上次复制位置"), systemImage: "clock.arrow.circlepath", isOn: $_useLastExportLocation)
            } footer: {
                Text(.localized("是否记住文件上次复制/移动到的位置"))
            }

            Section {
                Picker(.localized("提取库"), systemImage: "archivebox.circle.fill", selection: $_extractionLibrary) {
                    ForEach(Options.extractionLibraryValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
            } footer: {
                Text(.localized("选择用于提取归档的库。建议对大文件或Zip不工作时使用ZIPFoundation。"))
            }
		}
    }
}
