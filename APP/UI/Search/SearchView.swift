//
//  SearchView.swift
//
//  Created by pxx917144686 on 2025/08/19.
//
import SwiftUI
struct SearchView: View {
    @AppStorage("searchKey") var searchKey = ""
    @AppStorage("searchRegion") var searchRegion = "US"
    @AppStorage("searchHistory") var searchHistoryData = Data()
    @FocusState var searchKeyFocused
    @State var searchType = DeviceFamily.phone
    @EnvironmentObject var themeManager: ThemeManager
    @State var searching = false
    // 视图模式状态 - 改用@State确保实时更新
    @State var viewMode: ViewMode = .list
    @State var viewModeRefreshTrigger = UUID() // 添加刷新触发器
    // 视图模式枚举
    enum ViewMode: String, CaseIterable {
        case list = "list"
        case card = "card"
        var displayName: String {
            switch self {
            case .list: return "列表"
            case .card: return "卡片"
            }
        }
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .card: return "square.grid.2x2"
            }
        }
    }
    // Static country code to name mapping
    static let countryCodeMap: [String: String] = [
        "AE": "United Arab Emirates", "AG": "Antigua and Barbuda", "AI": "Anguilla", "AL": "Albania", "AM": "Armenia",
        "AO": "Angola", "AR": "Argentina", "AT": "Austria", "AU": "Australia", "AZ": "Azerbaijan",
        "BB": "Barbados", "BD": "Bangladesh", "BE": "Belgium", "BG": "Bulgaria", "BH": "Bahrain",
        "BM": "Bermuda", "BN": "Brunei", "BO": "Bolivia", "BR": "Brazil", "BS": "Bahamas",
        "BW": "Botswana", "BY": "Belarus", "BZ": "Belize", "CA": "Canada", "CH": "Switzerland",
        "CI": "Côte d'Ivoire", "CL": "Chile", "CN": "China", "CO": "Colombia", "CR": "Costa Rica",
        "CY": "Cyprus", "CZ": "Czech Republic", "DE": "Germany", "DK": "Denmark", "DM": "Dominica",
        "DO": "Dominican Republic", "DZ": "Algeria", "EC": "Ecuador", "EE": "Estonia", "EG": "Egypt",
        "ES": "Spain", "FI": "Finland", "FR": "France", "GB": "United Kingdom", "GD": "Grenada",
        "GE": "Georgia", "GH": "Ghana", "GR": "Greece", "GT": "Guatemala", "GY": "Guyana",
        "HK": "Hong Kong", "HN": "Honduras", "HR": "Croatia", "HU": "Hungary", "ID": "Indonesia",
        "IE": "Ireland", "IL": "Israel", "IN": "India", "IS": "Iceland", "IT": "Italy",
        "JM": "Jamaica", "JO": "Jordan", "JP": "Japan", "KE": "Kenya", "KN": "Saint Kitts and Nevis",
        "KR": "South Korea", "KW": "Kuwait", "KY": "Cayman Islands", "KZ": "Kazakhstan", "LB": "Lebanon",
        "LC": "Saint Lucia", "LI": "Liechtenstein", "LK": "Sri Lanka", "LT": "Lithuania", "LU": "Luxembourg",
        "LV": "Latvia", "MD": "Moldova", "MG": "Madagascar", "MK": "North Macedonia", "ML": "Mali",
        "MN": "Mongolia", "MO": "Macao", "MS": "Montserrat", "MT": "Malta", "MU": "Mauritius",
        "MV": "Maldives", "MX": "Mexico", "MY": "Malaysia", "NE": "Niger", "NG": "Nigeria",
        "NI": "Nicaragua", "NL": "Netherlands", "NO": "Norway", "NP": "Nepal", "NZ": "New Zealand",
        "OM": "Oman", "PA": "Panama", "PE": "Peru", "PH": "Philippines", "PK": "Pakistan",
        "PL": "Poland", "PT": "Portugal", "PY": "Paraguay", "QA": "Qatar", "RO": "Romania",
        "RS": "Serbia", "RU": "Russia", "SA": "Saudi Arabia", "SE": "Sweden", "SG": "Singapore",
        "SI": "Slovenia", "SK": "Slovakia", "SN": "Senegal", "SR": "Suriname", "SV": "El Salvador",
        "TC": "Turks and Caicos", "TH": "Thailand", "TN": "Tunisia", "TR": "Turkey", "TT": "Trinidad and Tobago",
        "TW": "Taiwan", "TZ": "Tanzania", "UA": "Ukraine", "UG": "Uganda", "US": "United States",
        "UY": "Uruguay", "UZ": "Uzbekistan", "VC": "Saint Vincent and the Grenadines", "VE": "Venezuela",
        "VG": "British Virgin Islands", "VN": "Vietnam", "YE": "Yemen", "ZA": "South Africa"
    ]
    static let storeFrontCodeMap = [
        "AE": "143481", "AG": "143540", "AI": "143538", "AL": "143575", "AM": "143524",
        "AO": "143564", "AR": "143505", "AT": "143445", "AU": "143460", "AZ": "143568",
        "BB": "143541", "BD": "143490", "BE": "143446", "BG": "143526", "BH": "143559",
        "BM": "143542", "BN": "143560", "BO": "143556", "BR": "143503", "BS": "143539",
        "BW": "143525", "BY": "143565", "BZ": "143555", "CA": "143455", "CH": "143459",
        "CI": "143527", "CL": "143483", "CN": "143465", "CO": "143501", "CR": "143495",
        "CY": "143557", "CZ": "143489", "DE": "143443", "DK": "143458", "DM": "143545",
        "DO": "143508", "DZ": "143563", "EC": "143509", "EE": "143518", "EG": "143516",
        "ES": "143454", "FI": "143447", "FR": "143442", "GB": "143444", "GD": "143546",
        "GE": "143615", "GH": "143573", "GR": "143448", "GT": "143504", "GY": "143553",
        "HK": "143463", "HN": "143510", "HR": "143494", "HU": "143482", "ID": "143476",
        "IE": "143449", "IL": "143491", "IN": "143467", "IS": "143558", "IT": "143450",
        "JM": "143511", "JO": "143528", "JP": "143462", "KE": "143529", "KN": "143548",
        "KR": "143466", "KW": "143493", "KY": "143544", "KZ": "143517", "LB": "143497",
        "LC": "143549", "LI": "143522", "LK": "143486", "LT": "143520", "LU": "143451",
        "LV": "143519", "MD": "143523", "MG": "143531", "MK": "143530", "ML": "143532",
        "MN": "143592", "MO": "143515", "MS": "143547", "MT": "143521", "MU": "143533",
        "MV": "143488", "MX": "143468", "MY": "143473", "NE": "143534", "NG": "143561",
        "NI": "143512", "NL": "143452", "NO": "143457", "NP": "143484", "NZ": "143461",
        "OM": "143562", "PA": "143485", "PE": "143507", "PH": "143474", "PK": "143477",
        "PL": "143478", "PT": "143453", "PY": "143513", "QA": "143498", "RO": "143487",
        "RS": "143500", "RU": "143469", "SA": "143479", "SE": "143456", "SG": "143464",
        "SI": "143499", "SK": "143496", "SN": "143535", "SR": "143554", "SV": "143506",
        "TC": "143552", "TH": "143475", "TN": "143536", "TR": "143480", "TT": "143551",
        "TW": "143470", "TZ": "143572", "UA": "143492", "UG": "143537", "US": "143441",
        "UY": "143514", "UZ": "143566", "VC": "143550", "VE": "143502", "VG": "143543",
        "VN": "143471", "YE": "143571", "ZA": "143472"
    ]
    let regionKeys = Array(SearchView.storeFrontCodeMap.keys.sorted())
    @State var searchInput: String = ""
    @State var searchResult: [iTunesSearchResult] = []
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    private let pageSize = 20
    @State var searchHistory: [String] = []
    @State var showSearchHistory = false
    @State var showRegionPicker = false
    @State var isHovered = false
    @State var searchError: String? = nil
    @State var searchSuggestions: [String] = []
    @State var searchCache: [String: [iTunesSearchResult]] = [:]
    @State var showSearchSuggestions = false
    @StateObject var vm = AppStore.this
    @State private var animateHeader = false
    @State private var animateCards = false
    @State private var animateSearchBar = false
    @State private var animateResults = false
    

    // 版本选择相关状态
    @State private var showVersionPicker = false
    @State private var selectedApp: iTunesSearchResult?
    @State private var availableVersions: [AppVersion] = []
    @State private var isLoadingVersions = false
    @State private var versionError: String?
    var possibleReigon: Set<String> {
        Set(vm.accounts.map(\.countryCode))
    }
    var body: some View {
        NavigationView {
            ZStack {
                // 统一背景色 - 与其他界面保持一致
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                // 顶部安全区域占位 - 真机适配
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44)
                            .onAppear {
                                print("[SearchView] 顶部安全区域: \(geometry.safeAreaInsets.top)")
                            }
                    }
                    .frame(height: 44) // 固定高度，避免布局跳动
                    
                    // 主要内容区域
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                // 搜索头部区域
                                modernSearchBar
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateHeader)
                                    .id("searchBar")
                                
                                // 分类选择器
                                categorySelector
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateHeader)
                                
                                // 搜索结果区域
                                searchResultsSection
                                    .scaleEffect(animateResults ? 1 : 0.95)
                                    .opacity(animateResults ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateResults)
                            }
                        }
                        .refreshable {
                            if !searchKey.isEmpty {
                                await performSearch()
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadSearchHistory()
            // 强制刷新UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 强制刷新UI")
                startAnimations()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in
            // 接收强制刷新通知 - 真机适配
            print("[SearchView] 接收到强制刷新通知")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 真机适配强制刷新完成")
                startAnimations()
            }
        }
        .sheet(isPresented: $showVersionPicker) {
            versionPickerSheet
        }
    }
    // MARK: - 现代化搜索栏
    var modernSearchBar: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                // 搜索输入框
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(searchKeyFocused ? themeManager.accentColor : (themeManager.selectedTheme == .dark ? ModernDarkColors.textSecondary : .secondary))
                    TextField("搜索应用、游戏和更多内容...", text: $searchKey)
                        .font(.bodyLarge)
                        .focused($searchKeyFocused)
                        .onChange(of: searchKey) { newValue in
                            if !newValue.isEmpty {
                                showSearchSuggestions = true
                                searchSuggestions = getSearchSuggestions(for: newValue)
                            } else {
                                showSearchSuggestions = false
                                searchSuggestions = []
                            }
                        }
                        .onSubmit {
                            showSearchSuggestions = false
                            Task {
                                await performSearch()
                            }
                        }
                    if !searchKey.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchKey = ""
                                searchResult = []
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(themeManager.selectedTheme == .dark ? ModernDarkColors.surfaceElevated : Color.surfacePrimary)
                        .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(
                            searchKeyFocused ? Color.primaryAccent : Color.clear,
                            lineWidth: 2
                        )
                )
                // 搜索按钮
                Button {
                    Task {
                        await performSearch()
                    }
                } label: {
                    Group {
                        if searching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(searchKey.isEmpty || searching)
                .scaleEffect(searching ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: searching)
            }
            // 搜索类型和地区选择
            HStack(spacing: Spacing.md) {
                // 搜索类型选择器
                Menu {
                    ForEach(DeviceFamily.allCases, id: \.self) { type in
                        Button {
                            searchType = type
                        } label: {
                            HStack {
                                Image(systemName: "iphone")
                                Text(type.displayName)
                                if searchType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14, weight: .medium))
                        Text(searchType.displayName)
                            .font(.labelMedium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(themeManager.accentColor.opacity(0.1))
                    )
                }
                Spacer()
                // 地区选择器
                buildRegionSelector()
            }
        }
    }
    // MARK: - 搜索历史区域
    var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("最近搜索", systemImage: "clock.arrow.circlepath")
                    .font(.labelLarge)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除全部") {
                    withAnimation(.easeInOut) {
                        clearSearchHistory()
                    }
                }
                .font(.labelMedium)
                .foregroundColor(.primaryAccent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(searchHistory.prefix(8), id: \.self) { history in
                        Button {
                            searchKey = history
                            showSearchHistory = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(history)
                                    .font(.labelMedium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.surfaceSecondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    // MARK: - 搜索建议区域
    var searchSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("搜索建议")
                    .font(.titleSmall)
                Spacer()
                Button("关闭") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchSuggestions = false
                    }
                }
                .font(.labelMedium)
                .foregroundColor(.primaryAccent)
            }
            .foregroundColor(.primaryAccent)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(searchSuggestions.prefix(8), id: \.self) { suggestion in
                        Button {
                            searchKey = suggestion
                            showSearchSuggestions = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(suggestion)
                                    .font(.labelMedium)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.surfaceSecondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    // MARK: - 分类选择器
    var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.bottom, Spacing.lg)
    }
    // MARK: - 搜索结果区域
    var searchResultsSection: some View {
        VStack(spacing: Spacing.lg) {
            if !searchResult.isEmpty {
                // 结果统计和视图切换器
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("找到 \(searchResult.count) 个结果")
                            .font(.titleMedium)
                            .foregroundColor(.primary)
                        if !searchInput.isEmpty {
                            Text("关于 \"\(searchInput)\"")
                                .font(.bodySmall)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // 视图模式切换器
                    viewModeToggle
                }
                .padding(.horizontal, Spacing.lg)
            }
            // 搜索结果网格/列表
            if let error = searchError {
                searchErrorView(error: error)
            } else if searching {
                searchingIndicator
            } else if searchResult.isEmpty {
                emptyStateView
            } else {
                searchResultsGrid
                    .id("searchResultsGrid-\(viewMode.rawValue)-\(viewModeRefreshTrigger)") // 添加ID确保视图刷新
            }
        }
    }
    // MARK: - 搜索中指示器
    var searchingIndicator: some View {
        VStack(spacing: Spacing.lg) {
            // 动画加载指示器
            ZStack {
                Circle()
                    .stroke(Color.primaryAccent.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color.primaryAccent, Color.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(searching ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: searching
                    )
            }
            VStack(spacing: Spacing.xs) {
                Text("正在搜索...")
                    .font(.titleMedium)
                    .foregroundColor(.primary)
                Text("为您寻找最佳结果")
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
    }
    // MARK: - 空状态视图
    var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            // 空状态图标
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .scaleEffect(animateCards ? 1.1 : 1)
                .opacity(animateCards ? 1 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: animateCards
                )
            VStack(spacing: Spacing.sm) {
                Text("APP降级")
                    .font(.titleLarge)
                    .foregroundColor(.primary)
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // 推荐搜索
            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("搜索历史")
                        .font(.labelLarge)
                        .foregroundColor(.secondary)
                    HStack(spacing: Spacing.sm) {
                        ForEach(searchHistory.prefix(3), id: \.self) { history in
                            Button {
                                searchKey = history
                                Task {
                                    await performSearch()
                                }
                            } label: {
                                Text(history)
                                    .font(.labelMedium)
                                    .foregroundColor(.primaryAccent)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        Capsule()
                                            .stroke(Color.primaryAccent.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .padding(.horizontal, Spacing.lg)
    }
    // MARK: - 搜索错误视图
    func searchErrorView(error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            // 错误图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.materialRed.opacity(0.1), Color.materialRed.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.materialRed.opacity(0.8))
            }
            VStack(spacing: Spacing.sm) {
                Text("搜索出现问题")
                    .font(.titleLarge)
                    .foregroundColor(.primary)
                Text(error)
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // 重试按钮
            Button {
                searchError = nil
                Task {
                    await performSearch()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("重试")
                        .font(.labelLarge)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.primaryAccent, Color.primaryAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .padding(.horizontal, Spacing.lg)
    }

    
    // MARK: - 视图模式切换器
    var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    print("[SearchView] 视图模式切换: \(viewMode) -> \(mode)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                        // 强制刷新视图模式
                        viewModeRefreshTrigger = UUID()
                    }
                    print("[SearchView] 视图模式已更新: \(viewMode), 刷新触发器: \(viewModeRefreshTrigger)")
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.displayName)
                            .font(.labelMedium)
                    }
                    .foregroundColor(viewMode == mode ? .white : themeManager.accentColor)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(viewMode == mode ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(themeManager.selectedTheme == .dark ? ModernDarkColors.surfaceSecondary : Color.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    // MARK: - 搜索结果网格
    var searchResultsGrid: some View {
        Group {
            if viewMode == .card {
                // 卡片视图 - 网格布局
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ], spacing: Spacing.md) {
                    ForEach(searchResult.indices, id: \.self) { index in
                        let item = searchResult[index]
                        resultCardView(item: item, index: index)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .onAppear {
                    print("[SearchView] 显示卡片视图，结果数量: \(searchResult.count)")
                }
            } else {
                // 列表视图
                LazyVStack(spacing: Spacing.md) {
                    ForEach(searchResult.indices, id: \.self) { index in
                        let item = searchResult[index]
                        resultListView(item: item, index: index)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .onAppear {
                    print("[SearchView] 显示列表视图，结果数量: \(searchResult.count)")
                }
            }
            // 加载更多指示器
            if isLoadingMore {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载更多...")
                        .font(.labelMedium)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, Spacing.lg)
            }
        }
    }
    // MARK: - 结果卡片视图
    func resultCardView(item: iTunesSearchResult, index: Int) -> some View {
        Button {
            // 只调用loadVersionsForApp，让它统一管理状态设置
            Task {
                await loadVersionsForApp(item)
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // 应用图标
                AsyncImage(url: URL(string: item.artworkUrl512 ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(
                            LinearGradient(
                                colors: [Color.surfaceSecondary, Color.surfaceTertiary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                // 应用信息
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(item.name)
                        .font(.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.artistName ?? "未知开发者")
                        .font(.bodySmall)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                // 价格和版本信息
                HStack(spacing: Spacing.xs) {
                    if let price = item.formattedPrice {
                        Text(price)
                            .font(.labelSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeManager.accentColor)
                            )
                    }
                    Text("v\(item.version)")
                        .font(.labelSmall)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.surfaceSecondary)
                        )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(themeManager.selectedTheme == .dark ? ModernDarkColors.surfaceElevated : Color.surfacePrimary)
                    .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onAppear {
            // 当显示到倒数第3个项目时开始预加载
            if index >= searchResult.count - 3 && !isLoadingMore && searchResult.count >= pageSize {
                loadMoreResults()
            }
        }
    }
    // MARK: - 结果列表视图
    func resultListView(item: iTunesSearchResult, index: Int) -> some View {
        Button {
            // 只调用loadVersionsForApp，让它统一管理状态设置
            Task {
                await loadVersionsForApp(item)
            }
        } label: {
            HStack(spacing: Spacing.md) {
                // 应用图标
                AsyncImage(url: URL(string: item.artworkUrl512 ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfaceSecondary)
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                // 应用信息
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(item.name)
                        .font(.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.artistName ?? "未知开发者")
                        .font(.bodySmall)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    HStack(spacing: Spacing.xs) {
                        if let price = item.formattedPrice {
                            Text(price)
                                .font(.labelSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryAccent)
                        }
                        Text("v\(item.version)")
                            .font(.labelSmall)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(themeManager.selectedTheme == .dark ? ModernDarkColors.surfaceElevated : Color.surfacePrimary)
                    .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if index == searchResult.count - 1 && !isLoadingMore {
                loadMoreResults()
            }
        }
    }
    // MARK: - 地区选择器
    func buildRegionSelector() -> some View {
        Menu {
            ForEach(regionKeys, id: \.self) { code in
                if let name = SearchView.countryCodeMap[code] {
                    Button {
                        searchRegion = code
                    } label: {
                        HStack {
                            Text("\(flag(country: code)) \(name)")
                            if searchRegion == code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(flag(country: searchRegion))
                    .font(.system(size: 14))
                Text(SearchView.countryCodeMap[searchRegion] ?? searchRegion)
                    .font(.labelMedium)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(themeManager.selectedTheme == .dark ? ModernDarkColors.accentSecondary : .secondaryAccent)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill((themeManager.selectedTheme == .dark ? ModernDarkColors.accentSecondary : .secondaryAccent).opacity(0.1))
            )
        }
    }
    // MARK: - 辅助方法
    func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateHeader = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateResults = true
        }
    }
    

    func flag(country: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in country.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
    @MainActor
    func performSearch() async {
        guard !searchKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.easeInOut) {
            searching = true
            searchResult = []
            currentPage = 1
            searchError = nil
        }
        searchInput = searchKey
        addToSearchHistory(searchKey)
        showSearchHistory = false
        // Check cache first
        let cacheKey = "\(searchKey)_\(searchType.rawValue)_\(searchRegion)"
        if let cachedResult = searchCache[cacheKey] {
            await MainActor.run {
                withAnimation(.spring()) {
                    searchResult = cachedResult
                    searching = false
                }
            }
            return
        }
        do {
            // Use new iTunesClient implementation
            let response = try await iTunesClient.shared.search(
                term: searchKey,
                limit: pageSize,
                countryCode: searchRegion,
                deviceFamily: searchType
            )
            let results = response ?? []
            await MainActor.run {
                withAnimation(.spring()) {
                    searchResult = results
                    searching = false
                    // Cache the result
                    searchCache[cacheKey] = results
                    // Generate search suggestions based on results
                    updateSearchSuggestions(from: results)
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut) {
                    searching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
    func loadSearchHistory() {
        if let data = try? JSONDecoder().decode([String].self, from: searchHistoryData) {
            searchHistory = data
        }
    }
    func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            searchHistoryData = data
        }
    }
    func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        // 移除重复项
        searchHistory.removeAll { $0 == trimmedQuery }
        // 添加到开头
        searchHistory.insert(trimmedQuery, at: 0)
        // 限制历史记录数量
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        saveSearchHistory()
    }
    func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
        showSearchHistory = false
    }
    func loadMoreResults() {
        guard !isLoadingMore && !searching && !searchKey.isEmpty else { return }
        isLoadingMore = true
        currentPage += 1
        Task {
            do {
                let response = try await iTunesClient.shared.search(
                    term: searchKey,
                    limit: pageSize,
                    countryCode: searchRegion,
                    deviceFamily: searchType
                )
                let results = response ?? []
                await MainActor.run {
                    // 只有当返回的结果不为空时才添加
                    if !results.isEmpty {
                        searchResult.append(contentsOf: results)
                    }
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                    currentPage -= 1
                    searchError = error.localizedDescription
                }
            }
        }
    }
    func updateSearchSuggestions(from results: [iTunesSearchResult]) {
        var suggestions: Set<String> = []
        for result in results.prefix(10) {
            // Add app names as suggestions
            let appName = result.name
            if !appName.isEmpty {
                suggestions.insert(appName)
            }
            // Add artist names as suggestions
            if let artistName = result.artistName, !artistName.isEmpty {
                suggestions.insert(artistName)
            }
        }
        searchSuggestions = Array(suggestions).sorted()
    }
    func clearSearchCache() {
        searchCache.removeAll()
    }
    func getSearchSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        let lowercaseQuery = query.lowercased()
        let historySuggestions = searchHistory.filter { $0.lowercased().contains(lowercaseQuery) }
        let dynamicSuggestions = searchSuggestions.filter { $0.lowercased().contains(lowercaseQuery) }
        return Array(Set(historySuggestions + dynamicSuggestions)).prefix(5).map { $0 }
    }
    // MARK: - Version Selection Methods
    func loadVersionsForApp(_ app: iTunesSearchResult) {
        // 首先同步设置selectedApp，确保UI立即更新
        selectedApp = app
        // 然后在Task中异步加载版本信息和更新其他状态
        Task {
            await MainActor.run {
                isLoadingVersions = true
                versionError = nil
                availableVersions = []
                // 显示版本选择器
                showVersionPicker = true
            }
            do {
                print("[SearchView] 开始加载应用版本: \(app.trackName)")
                // 获取已保存的账户信息
                guard let account = AuthenticationManager.shared.loadSavedAccount() else {
                    throw NSError(domain: "SearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录账户，无法获取版本信息"])
                }
                // 使用 StoreClient 获取版本信息
                let result = await StoreClient.shared.getAppVersions(
                    trackId: String(app.trackId),
                    account: account
                )
                switch result {
                case .success(let versions):
                    await MainActor.run {
                        self.availableVersions = versions
                        self.isLoadingVersions = false
                        print("[SearchView] 成功加载 \(versions.count) 个版本")
                        for version in versions {
                            print("[SearchView] 版本: \(version.versionString) - ID: \(version.versionId)")
                        }
                    }
                case .failure(let error):
                    throw error
                }
            } catch {
                await MainActor.run {
                    self.versionError = error.localizedDescription
                    self.isLoadingVersions = false
                    print("[SearchView] 加载版本失败: \(error)")
                }
            }
        }
    }
    // 现代化版本选择器视图
    var versionPickerSheet: some View {
        NavigationView {
            ZStack {
                // 现代化背景渐变
                LinearGradient(
                    colors: themeManager.selectedTheme == .dark ? 
                        [ModernDarkColors.primaryBackground, ModernDarkColors.surfaceSecondary] :
                        [Color.surfacePrimary, Color.surfaceSecondary.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 版本列表区域 - 直接显示，移除应用头部
                versionListContent
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(themeManager.selectedTheme == .dark ? 
                                  ModernDarkColors.surfaceSecondary.opacity(0.5) : 
                                  Color.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("返回") {
                        showVersionPicker = false
                    }
                    .foregroundColor(themeManager.accentColor)
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }

    // 版本列表内容视图
    private var versionListContent: some View {
        Group {
            if isLoadingVersions {
                loadingVersionsView
            } else if let error = versionError {
                errorView(error: error)
            } else if availableVersions.isEmpty {
                emptyVersionsView
            } else {
                versionsListView
            }
        }
    }
    private var loadingVersionsView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载历史版本...")
                .font(.bodyMedium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func errorView(error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.materialRed)
            Text("加载失败")
                .font(.titleMedium)
                .fontWeight(.semibold)
            Text(error)
                .font(.bodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                if let app = selectedApp {
                    loadVersionsForApp(app)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var emptyVersionsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无历史版本")
                .font(.titleMedium)
                .fontWeight(.semibold)
            Text("该应用暂时没有可用的历史版本")
                .font(.bodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var versionsListView: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // 应用名称标题
                VStack(spacing: Spacing.sm) {
                    Text(selectedApp?.trackName ?? "APP")
                        .font(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(selectedApp?.artistName ?? "Unknown Developer")
                        .font(.bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                
                // 版本数量统计
                HStack {
                    Text("历史版本")
                        .font(.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(availableVersions.count) 个版本")
                        .font(.bodySmall)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                // 版本列表
                ForEach(availableVersions, id: \.versionId) {
                    createModernVersionRow(version: $0)
                }
            }
            .padding(.bottom, Spacing.lg)
        }
    }
    private func createModernVersionRow(version: AppVersion) -> some View {
        HStack(spacing: Spacing.md) {
            // 版本信息区域
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // 版本号
                HStack(spacing: Spacing.sm) {
                    Text("版本 \(version.versionString)")
                        .font(.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                
                // 版本ID
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("ID: \(version.versionId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 下载按钮
            Button(action: {
                Task {
                    if let app = selectedApp {
                        await downloadVersion(app: app, version: version)
                    }
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                    Text("下载")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.selectedTheme == .dark ? 
                      ModernDarkColors.surfaceSecondary.opacity(0.3) : 
                      Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .padding(.horizontal, Spacing.lg)
    }
    @MainActor
    func downloadVersion(app: iTunesSearchResult, version: AppVersion) async {
        showVersionPicker = false
        guard vm.accounts.first != nil else {
            print("[SearchView] 错误：没有可用的账户")
            return
        }
        let appId = app.trackId
        print("[SearchView] 开始下载应用: \(app.trackName) 版本: \(version.versionString)")
        // 使用UnifiedDownloadManager添加下载请求并开始下载
        let downloadId = UnifiedDownloadManager.shared.addDownload(
            bundleIdentifier: app.bundleId,
            name: app.trackName,
            version: version.versionString,
            identifier: appId,
            iconURL: app.artworkUrl512,
            versionId: version.versionId
        )
        print("[SearchView] 已将下载请求添加到下载管理器，ID: \(downloadId)")
        // 开始下载
        if let request = UnifiedDownloadManager.shared.downloadRequests.first(where: { $0.id == downloadId }) {
            UnifiedDownloadManager.shared.startDownload(for: request)
        } else {
            print("[SearchView] 无法找到刚添加的下载请求")
        }
    }
}