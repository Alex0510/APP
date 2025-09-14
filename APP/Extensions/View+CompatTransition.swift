import SwiftUI

extension View {
	@ViewBuilder
	func compatTransition() -> some View {
		if #available(iOS 17.0, *) {
			self.contentTransition(.opacity)
		} else {
			self.transition(.opacity)
		}
	}
}
