
import SwiftUI
import NimbleViews
import NukeUI

struct SourcesCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	
	var source: AltSource
	
	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		
		FRIconCellView(
			title: source.name ?? .localized("未知"),
			subtitle: source.sourceURL?.absoluteString ?? "",
			iconUrl: source.iconURL
		)
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
			? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(Color(.quaternarySystemFill))
			: nil
		)
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("删除"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("复制"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}
