import SwiftUI
struct FRExpirationPillView: View {
	let title: String
	let revoked: Bool
	let expiration: Date.ExpirationInfo?
	
	var body: some View {
		let textLabel = revoked
		? .localized("已撤销")
		: expiration?.formatted ?? title
		
		let textForeground = (expiration == nil)
		? Color.accentColor
		: .white
		
		let textBackground = revoked
		? .red
		: expiration?.color.opacity(0.85) ?? Color(uiColor: .quaternarySystemFill)
		
		Text(textLabel)
			.lineLimit(0)
			.font(.headline.bold())
			.foregroundStyle(textForeground)
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background(textBackground)
			.clipShape(Capsule())
	}
}

