import SwiftUI

extension Image {
	func appIconStyle(
		size: CGFloat = 56,
		lineWidth: CGFloat = 1,
		isCircle: Bool = false,
		background: Color = .clear
	) -> some View {
		self.resizable()
			.scaledToFit()
			.frame(width: size, height: size)
			.background(
				RoundedRectangle(cornerRadius: isCircle ? (size * 2) : (size * 0.2337), style: .continuous)
					.fill(background)
			)
			.overlay {
				RoundedRectangle(cornerRadius: isCircle ? (size * 2) : (size * 0.2337), style: .continuous)
					.strokeBorder(.gray.opacity(0.3), lineWidth: lineWidth)
			}
			.clipShape(RoundedRectangle(cornerRadius: isCircle ? (size * 2) : (size * 0.2337), style: .continuous))
	}
}