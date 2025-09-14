import SwiftUI

struct NBButton: View {
	let title: String
	let systemImage: String?
	let style: Style

	enum Style {
		case text
		case prominent
		case icon
	}

	init(_ title: String, systemImage: String? = nil, style: Style = .text) {
		self.title = title
		self.systemImage = systemImage
		self.style = style
	}

	var body: some View {
		Group {
			if let systemImage = systemImage, !systemImage.isEmpty {
				Label(title, systemImage: systemImage)
			} else {
				Text(title)
			}
		}
		.font(style == .prominent ? .headline.bold() : .body)
		.padding(.horizontal, style == .prominent ? 24 : 0)
		.padding(.vertical, style == .prominent ? 12 : 0)
		.background(style == .prominent ? Color.accentColor : Color.clear)
		.foregroundColor(style == .prominent ? Color.white : Color.accentColor)
		.clipShape(Capsule())
	}
}
