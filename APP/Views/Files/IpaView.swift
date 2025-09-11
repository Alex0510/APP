//
//  IpaView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI

struct IpaView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "app.badge")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                Text("应用包")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("IPA文件管理")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("应用包")
        }
    }
}

#Preview {
    IpaView()
}
