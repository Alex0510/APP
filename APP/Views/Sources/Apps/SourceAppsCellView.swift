
import SwiftUI
import AltSourceKit
import NimbleViews
import Combine
import NukeUI

struct SourceAppsCellView: View {
	var source: ASRepository
	var app: ASRepository.App
	
	var body: some View {
		HStack(spacing: 2) {
			FRIconCellView(
				title: app.currentName,
				subtitle: Self.appDescription(app: app),
				iconUrl: app.iconURL
			)
			.overlay(alignment: .bottomLeading) {
				if let iconURL = source.currentIconURL {
					LazyImage(url: iconURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(Circle())
								.offset(x: 41, y: 4)
                        }
                    }
				}
			}
			DownloadButtonView(app: app)
		}
	}
	
	static func appDescription(app: ASRepository.App) -> String {
		let optionalComponents: [String?] = [
			app.currentVersion,
			app.currentDescription ?? .localized("一个很棒的应用")
		]
		
		let components: [String] = optionalComponents.compactMap { value in
			guard
				let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
				!trimmed.isEmpty
			else {
				return nil
			}
			
			return trimmed
		}
		
		return components.joined(separator: " • ")
	}
}
