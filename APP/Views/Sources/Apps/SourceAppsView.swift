//
//  SourceAppsView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

// MARK: - Extension: View (Enil)
extension SourceAppsView {
    enum SortOption: String, CaseIterable {
        case `default` = "default"
        case name
        case date
        
        var displayName: String {
            switch self {
            case .default:  .localized("默认")
        case .name:     .localized("名称")
        case .date:     .localized("日期")
            }
        }
    }
}

// MARK: - View
struct SourceAppsView: View {
    @AppStorage("Feather.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.default.rawValue
    @AppStorage("Feather.sortAscending") private var _sortAscending: Bool = true
    
    @State private var _sortOption: SortOption = .default
    @State private var _selectedRoute: SourceAppRoute?
    
    @State var isLoading = true
    @State var hasLoadedOnce = false
    @State private var _searchText = ""
    var fromAppStore: Bool = false
    
    private var _navigationTitle: String {
        if fromAppStore {
            return .localized("第三方源")
        } else if object.count == 1 {
            return object[0].name ?? .localized("未知")
        } else {
            return .localized("%lld Sources", arguments: object.count)
        }
    }
    
    var object: [AltSource]
    @ObservedObject var viewModel: SourcesViewModel
    @State private var _sources: [ASRepository]?
    
    // MARK: Body
    var body: some View {
        ZStack {
            if
                let _sources,
                !_sources.isEmpty
            {
                SourceAppsTableRepresentableView(
                    sources: _sources,
                    searchText: $_searchText,
                    sortOption: $_sortOption,
                    sortAscending: $_sortAscending,
                    onSelect: {self._selectedRoute = $0}
                )
                .ignoresSafeArea()
            } else {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        ProgressView()
                        Label(.localized("获取中..."), systemImage: "")
                    } description: {
                        Text(.localized("卡住了？检查是否已添加任何源。"))
                    }
                }
                else { ProgressView() }
            }
        }
        .navigationTitle(_navigationTitle)
        .searchable(text: $_searchText, placement: .platform())
        .toolbarTitleMenu {
            if
                let _sources,
                _sources.count == 1
            {
                if let url = _sources[0].website {
                    Button(.localized("访问网站"), systemImage: "globe") {
                        UIApplication.open(url)
                    }
                }
                
                if let url = _sources[0].patreonURL {
                    Button(.localized("访问Patreon"), systemImage: "dollarsign.circle") {
                        UIApplication.open(url)
                    }
                }
            }
            
            Divider()
            
            Button(.localized("复制"), systemImage: "doc.on.doc") {
                UIPasteboard.general.string = object.map {
                    $0.sourceURL!.absoluteString
                }.joined(separator: "\n")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .toolbar {
            if fromAppStore {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SourcesView()
                    } label: {
                        Text(.localized("源"))
                    }
                }
            }
            
            NBToolbarMenu(
                systemImage: "line.3.horizontal.decrease",
                style: .icon,
                placement: .topBarTrailing
            ) {
                _sortActions()
            }
        }
        .onAppear {
            if !hasLoadedOnce, viewModel.isFinished {
                _load()
                hasLoadedOnce = true
            }
            _sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
        }
        .onChange(of: viewModel.isFinished) { _, _ in
            _load()
        }
        .onChange(of: _sortOption) { _, newValue in
            _sortOptionRawValue = newValue.rawValue
        }
        .navigationDestinationIfAvailable(item: $_selectedRoute) { route in
            SourceAppsDetailView(source: route.source, app: route.app)
        }
        
    }
    
    private func _load() {
        isLoading = true
        
        Task {
            let loadedSources = object.compactMap { viewModel.sources[$0] }
            _sources = loadedSources
            withAnimation(.easeIn(duration: 0.2)) {
                isLoading = false
            }
        }
    }
    
    struct SourceAppRoute: Identifiable, Hashable {
        let source: ASRepository
        let app: ASRepository.App
        let id: String = UUID().uuidString
    }
}

// MARK: - Extension: View (Sort)
extension SourceAppsView {
    @ViewBuilder
    private func _sortActions() -> some View {
        Section(.localized("筛选条件")) {
            ForEach(SortOption.allCases, id: \.displayName) { opt in
                _sortButton(for: opt)
            }
        }
    }
    
    private func _sortButton(for option: SortOption) -> some View {
        Button {
            if _sortOption == option {
                _sortAscending.toggle()
            } else {
                _sortOption = option
                _sortAscending = true
            }
        } label: {
            HStack {
                Text(option.displayName)
                Spacer()
                if _sortOption == option {
                    Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
}

import SwiftUI

extension View {
    @ViewBuilder
    func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        if #available(iOS 17, *) {
            self.navigationDestination(item: item, destination: destination)
        } else {
            self
        }
    }
}
