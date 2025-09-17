
import SwiftUI
import NimbleViews

struct SigningOptionsView: View {
	@Binding var options: Options
	var temporaryOptions: Options?
	
	var body: some View {
		if (temporaryOptions == nil) {
			NBSection(.localized("保护")) {
				_toggle(
					.localized("PPQ保护"),
					systemImage: "shield",
					isOn: $options.ppqProtection,
					temporaryValue: temporaryOptions?.ppqProtection
				)
			} footer: {
				Text(.localized("启用任何保护都会在您签名的应用的bundle标识符后附加一个随机字符串，这是为了确保您的Apple ID不会被Apple标记。但是，使用签名服务时可以忽略此选项。"))
			}
		}
		
		NBSection(.localized("常规")) {
			Self.picker(
				.localized("外观"),
				systemImage: "paintpalette",
				selection: $options.appAppearance,
				values: Options.AppAppearance.allCases
			)
			
			Self.picker(
				.localized("最低要求"),
				systemImage: "ruler",
				selection: $options.minimumAppRequirement,
				values: Options.MinimumAppRequirement.allCases
			)
		}
		
		Section {
			Self.picker(
				.localized("签名类型"),
				systemImage: "signature",
				selection: $options.signingOption,
				values: Options.SigningOption.allCases
			)
		}
		
		NBSection(.localized("应用功能")) {
			_toggle(
				.localized("文件共享"),
				systemImage: "folder.badge.person.crop",
				isOn: $options.fileSharing,
				temporaryValue: temporaryOptions?.fileSharing
			)
			
			_toggle(
				.localized("iTunes文件共享"),
				systemImage: "music.note.list",
				isOn: $options.itunesFileSharing,
				temporaryValue: temporaryOptions?.itunesFileSharing
			)
			
			_toggle(
				.localized("Pro Motion"),
				systemImage: "speedometer",
				isOn: $options.proMotion,
				temporaryValue: temporaryOptions?.proMotion
			)
			
			_toggle(
				.localized("游戏模式"),
				systemImage: "gamecontroller",
				isOn: $options.gameMode,
				temporaryValue: temporaryOptions?.gameMode
			)
			
			_toggle(
				.localized("iPad全屏"),
				systemImage: "ipad.landscape",
				isOn: $options.ipadFullscreen,
				temporaryValue: temporaryOptions?.ipadFullscreen
			)
		}
		
		NBSection(.localized("移除")) {
			_toggle(
				.localized("移除URL方案"),
				systemImage: "ellipsis.curlybraces",
				isOn: $options.removeURLScheme,
				temporaryValue: temporaryOptions?.removeURLScheme
			)
			
			_toggle(
				.localized("移除配置文件"),
				systemImage: "doc.badge.gearshape",
				isOn: $options.removeProvisioning,
				temporaryValue: temporaryOptions?.removeProvisioning
			)
		} footer: {
			Text(.localized("移除配置文件将在签名时排除嵌入应用程序内的mobileprovision文件，以帮助防止任何检测。"))
		}
		
		Section {
			_toggle(
				.localized("强制本地化"),
				systemImage: "character.bubble",
				isOn: $options.changeLanguageFilesForCustomDisplayName,
				temporaryValue: temporaryOptions?.changeLanguageFilesForCustomDisplayName
			)
		} footer: {
			Text(.localized("默认情况下，应用的本地化标题不会被更改，但此选项会覆盖它。"))
		}
		
		NBSection(.localized("签名后")) {
            _toggle(
                .localized("签名后安装"),
                systemImage: "arrow.down.circle",
                isOn: $options.post_installAppAfterSigned,
                temporaryValue: temporaryOptions?.post_installAppAfterSigned
            )
			_toggle(
				.localized("签名后删除"),
				systemImage: "trash",
				isOn: $options.post_deleteAppAfterSigned,
				temporaryValue: temporaryOptions?.post_deleteAppAfterSigned
			)
		} footer: {
			Text(.localized("这将在签名后删除您导入的应用程序，以节省不必要的空间。"))
		}
		
		NBSection(.localized("测试性")) {
			_toggle(
				.localized("用ElleKit替换Substrate"),
				systemImage: "pencil",
				isOn: $options.experiment_replaceSubstrateWithEllekit,
				temporaryValue: temporaryOptions?.experiment_replaceSubstrateWithEllekit
			)
		}
	}
	
	@ViewBuilder
	static func picker<SelectionValue: Hashable, T: Hashable & LocalizedDescribable>(
		_ title: String,
		systemImage: String,
		selection: Binding<SelectionValue>,
		values: [T]
	) -> some View {
		Picker(selection: selection) {
			ForEach(values, id: \.self) { value in
				Text(value.localizedDescription)
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
					Text(title).bold()
				} else {
					Text(title)
				}
			} icon: {
				Image(systemName: systemImage)
			}
		}
	}
}
