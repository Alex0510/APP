import SwiftUI
import NukeUI
struct FRIconCellView: View {
	var title: String
	var subtitle: String
	var iconUrl: URL?
	var size: CGFloat = 56
	var isCircle: Bool = false
	
	var body: some View {
		HStack(spacing: 18) {
			if let iconURL = iconUrl {
                LazyImage(url: iconURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .applyClipping(isCircle: isCircle)
                    } else {
                        standardIcon
                    }
                }
			} else {
				standardIcon
			}
			
			VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.font(.headline)
				.lineLimit(nil)
			Text(subtitle)
				.font(.subheadline)
				.foregroundColor(.secondary)
				.lineLimit(nil)
		}
		}
	}
	
	var standardIcon: some View {
		Image("App_Unknown")
			.resizable()
			.scaledToFit()
			.frame(width: size, height: size)
            .applyClipping(isCircle: isCircle)
	}
}

fileprivate extension View {
    @ViewBuilder
    func applyClipping(isCircle: Bool) -> some View {
        if isCircle {
            self.clipShape(Circle())
        } else {
            self.clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 2)
        }
    }
}
