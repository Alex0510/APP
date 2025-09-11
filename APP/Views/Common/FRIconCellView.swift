//
//  FRIconCellView.swift
//  NimbleKit
//
//  Created by samara on 3.05.2025.
//

import SwiftUI
import NukeUI
import NimbleViews

// MARK: - View
struct FRIconCellView: View {
	var title: String
	var subtitle: String
	var iconUrl: URL?
	var trailing: AnyView?
	
	init(
		title: String,
		subtitle: String,
		iconUrl: URL?,
		trailing: AnyView? = nil
	) {
		self.title = title
		self.subtitle = subtitle
		self.iconUrl = iconUrl
		self.trailing = trailing
	}
	
	// MARK: Body
	var body: some View {
		HStack(spacing: 9) {
			if let iconURL = iconUrl {
				LazyImage(source: iconURL) { state in
					if let image = state.image {
						image
							.frame(width: 56, height: 56)
							.clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
					} else {
						standardIcon
					}
				}
			} else {
				standardIcon
			}
			
			NBTitleWithSubtitleView(
				title: title,
				subtitle: subtitle,
				linelimit: 0
			)
			
			if let trailing = trailing {
				Spacer()
				trailing
			}
		}
	}
	
	var standardIcon: some View {
		Image("App_Unknown")
			.appIconStyle()
	}
}
