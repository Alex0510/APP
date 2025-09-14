import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

struct SourcesView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#if !NIGHTLY && !DEBUG
	@AppStorage("Feather.shouldStar") private var _shouldStar: Int = 0
	#endif
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
	@State private var _addingSourceLoading = false
	@State private var _searchText = ""
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
	
	private var _filteredSources: [AltSource] {
		_sources.filter { _searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false) }
	}
	
	private var content: some View {
		NBListAdaptable {
			if !_filteredSources.isEmpty {
				allRepositoriesSection
				repositoriesSection
			}
		}
	}
	
	private var allRepositoriesSection: some View {
		Section {
			NavigationLink {
				SourceAppsView(object: Array(_sources), viewModel: viewModel)
			} label: {
				let isRegular = horizontalSizeClass != .compact
				HStack(spacing: 18) {
					Image("Repositories").appIconStyle()
					NBTitleWithSubtitleView(
						title: .localized("所有仓库"),
						subtitle: .localized("查看源")
					)
				}
				.padding(isRegular ? 12 : 0)
				.background(
					isRegular
					? RoundedRectangle(cornerRadius: 18, style: .continuous)
						.fill(Color(.quaternarySystemFill))
					: nil
				)
			}
			.buttonStyle(.plain)
		}
	}
	
	private var repositoriesSection: some View {
		NBSection(
			.localized("仓库"),
			secondary: _filteredSources.count.description
		) {
			ForEach(_filteredSources) { source in
				NavigationLink {
					SourceAppsView(object: [source], viewModel: viewModel)
				} label: {
					SourcesCellView(source: source)
				}
				.buttonStyle(.plain)
			}
		}
	}
	
	@available(iOS 17, *)
	private var emptyStateView: some View {
		ContentUnavailableView {
			Label(.localized("无仓库"), systemImage: "globe.desk.fill")
		} description: {
			Text(.localized("添加一个仓库，开始使用。"))
		} actions: {
			Button {
				_isAddingPresenting = true
			} label: {
				NBButton(.localized("添加来源"), systemImage: "arrow.down", style: .text)
			}
		}
	}
	
	var body: some View {
		NBNavigationView(.localized("来源")) {
			let contentView = content
			contentView
				.searchable(text: $_searchText, placement: .platform())
				.overlay {
					if _filteredSources.isEmpty {
						if #available(iOS 17, *) {
							emptyStateView
						}
					}
				}
				.toolbar {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing,
					isDisabled: _addingSourceLoading
				) {
					_isAddingPresenting = true
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
			SourcesAddView()
		}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
		#if !NIGHTLY && !DEBUG
		.onAppear {
			guard _shouldStar < 6 else { return }; _shouldStar += 1
			guard _shouldStar == 6 else { return }
			
			let github = UIAlertAction(title: "GitHub", style: .default) { _ in
				UIApplication.open("https://github.com/pxx917144686/APP")
			}
			
			let cancel = UIAlertAction(title: .localized("关闭"), style: .cancel)
			
			UIAlertController.showAlert(
				title: .localized("喜欢 %@?", arguments: Bundle.main.name ?? "Feather"),
				message: .localized("去GitHub关注！"),
				actions: [github, cancel]
			)
		}
		#endif
	}
}
