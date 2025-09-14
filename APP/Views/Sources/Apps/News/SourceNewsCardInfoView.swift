//
//  SourceNewsCardInfoView.swift
//  Feather
//
//  Created by samara on 8.06.2025.
//

import SwiftUI
import AltSourceKit
import NukeUI
import NimbleViews

// MARK: - View
struct SourceNewsCardInfoView: View {
	var new: ASRepository.News
	
	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					imageView
					
					VStack(alignment: .leading, spacing: 12) {
						Text(new.title)
							.font(.title.bold())
							.foregroundStyle(.tint)
							.multilineTextAlignment(.leading)
						
						if !new.caption.isEmpty {
							Text(new.caption)
								.font(.body)
								.foregroundStyle(.secondary)
								.multilineTextAlignment(.leading)
						}
						
						if let url = new.url {
							Button {
								UIApplication.shared.open(url)
							} label: {
                                HStack {
                                    Text(.localized("Open"))
                                    Image(systemName: "arrow.up.right")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(8)
							}
							.buttonStyle(.plain)
						}
						
						if let date = new.date?.date {
							Text(date.formatted(date: .abbreviated, time: .omitted))
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
					}
				}
				.frame(
					minWidth: 0,
					maxWidth: .infinity,
					minHeight: 0,
					maxHeight: .infinity,
					alignment: .topLeading
				)
				.padding()
			}
			.background(Color(uiColor: .systemBackground))
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
	}
    
    private var imageView: some View {
        ZStack(alignment: .bottomLeading) {
            let placeholderView = Color.gray.opacity(0.2)
            
            if let iconURL = new.imageURL {
                LazyImage(url: iconURL) {
                    if let image = $0.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .background(new.tintColor ?? Color.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
