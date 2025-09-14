//
//  SourceNewsCardView.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import SwiftUI
import AltSourceKit
import NukeUI
import NimbleViews

// MARK: - View
struct SourceNewsCardView: View {
	var new: ASRepository.News
	
	// MARK: Body
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			ZStack(alignment: .bottomLeading) {
                LazyImage(url: new.imageURL) {
                    if let image = $0.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                            .allowsHitTesting(false)
                    } else {
                        Color(.secondarySystemBackground)
                            .frame(height: 180)
                    }
                }
				
				LinearGradient(
					gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
					startPoint: .bottom,
					endPoint: .top
				)
				.frame(height: 70)
				.frame(maxWidth: .infinity, alignment: .bottom)
				.overlay(
					NBVariableBlurView()
						.rotationEffect(.degrees(180))
						.frame(height: 50)
						.frame(maxHeight: .infinity, alignment: .bottom)
				)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				
				Text(new.title)
					.font(.headline)
					.foregroundColor(.white)
					.lineLimit(2)
					.multilineTextAlignment(.leading)
					.padding()
			}
			.frame(width: 250, height: 150)
			.background(new.tintColor ?? Color.secondary)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
			)
		}
	}
}

