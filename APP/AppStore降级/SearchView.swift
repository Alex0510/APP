//
//  SearchView.swift
//  Created by pxx917144686 on 2025/09/08.
//
import SwiftUI
import UIKit
import AltSourceKit
import Vapor

struct SearchView: SwiftUI.View {
    
    @AppStorage("searchKey") var searchKey = ""
    @AppStorage("searchHistory") var searchHistoryData = Data()
    @FocusState var searchKeyFocused
    @State var searchType = DeviceFamily.phone
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appStore: AppStore  // 添加AppStore环境对象
    @State var searching = false
    
    // 视图模式状态 - 改用@State确保实时更新
    @State var viewMode: ViewMode = .list
    @State var viewModeRefreshTrigger = UUID() // 添加刷新触发器
    
    // 智能地区检测 - 移除硬编码的US
    @State var searchRegion: String = ""
    @State var showRegionPicker = false
    
    // 添加用户手动选择标志
    @State var isUserSelectedRegion: Bool = false
    
    // UI刷新触发器
    @State var uiRefreshTrigger = UUID()
    
    // MARK: - 登录相关状态
    @State var showLoginSheet = false
    @State var showAccountMenu = false
    
    
    // MARK: - 视图模式枚举
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
    
    // 智能地区选择器 - 计算属性
    var effectiveSearchRegion: String {
        // 优先级：用户手动选择 > 登录账户地区 > 默认地区
        if isUserSelectedRegion && !searchRegion.isEmpty {
            // 如果用户手动选择了地区，优先使用用户选择
            return searchRegion
        } else if let currentAccount = appStore.selectedAccount {
            // 直接返回登录账户地区
            return currentAccount.countryCode
        } else if !searchRegion.isEmpty {
            // 如果用户手动选择了地区，使用选择
            return searchRegion
        }
        // 默认返回美国地区
        return "US"
    }
    
    // iOS兼容的地区检测方法
    private func getRegionFromLanguageCode(_ languageCode: String) -> String {
        switch languageCode {
        case "zh":
            return "CN" // 中文 -> 中国
        case "ja":
            return "JP" // 日语 -> 日本
        case "ko":
            return "KR" // 韩语 -> 韩国
        case "de":
            return "DE" // 德语 -> 德国
        case "fr":
            return "FR" // 法语 -> 法国
        case "es":
            return "ES" // 西班牙语 -> 西班牙
        case "it":
            return "IT" // 意大利语 -> 意大利
        case "pt":
            return "BR" // 葡萄牙语 -> 巴西
        case "ru":
            return "RU" // 俄语 -> 俄罗斯
        case "ar":
            return "SA" // 阿拉伯语 -> 沙特阿拉伯
        case "hi":
            return "IN" // 印地语 -> 印度
        case "th":
            return "TH" // 泰语 -> 泰国
        case "vi":
            return "VN" // 越南语 -> 越南
        case "id":
            return "ID" // 印尼语 -> 印尼
        case "ms":
            return "MY" // 马来语 -> 马来西亚
        case "tr":
            return "TR" // 土耳其语 -> 土耳其
        case "pl":
            return "PL" // 波兰语 -> 波兰
        case "nl":
            return "NL" // 荷兰语 -> 荷兰
        case "sv":
            return "SE" // 瑞典语 -> 瑞典
        case "da":
            return "DK" // 丹麦语 -> 丹麦
        case "no":
            return "NO" // 挪威语 -> 挪威
        case "fi":
            return "FI" // 芬兰语 -> 芬兰
        case "cs":
            return "CZ" // 捷克语 -> 捷克
        case "hu":
            return "HU" // 匈牙利语 -> 匈牙利
        case "ro":
            return "RO" // 罗马尼亚语 -> 罗马尼亚
        case "bg":
            return "BG" // 保加利亚语 -> 保加利亚
        case "hr":
            return "HR" // 克罗地亚语 -> 克罗地亚
        case "sk":
            return "SK" // 斯洛伐克语 -> 斯洛伐克
        case "sl":
            return "SI" // 斯洛文尼亚语 -> 斯洛文尼亚
        case "et":
            return "EE" // 爱沙尼亚语 -> 爱沙尼亚
        case "lv":
            return "LV" // 拉脱维亚语 -> 拉脱维亚
        case "lt":
            return "LT" // 立陶宛语 -> 立陶宛
        case "el":
            return "GR" // 希腊语 -> 希腊
        case "he":
            return "IL" // 希伯来语 -> 以色列
        case "fa":
            return "IR" // 波斯语 -> 伊朗
        case "ur":
            return "PK" // 乌尔都语 -> 巴基斯坦
        case "bn":
            return "BD" // 孟加拉语 -> 孟加拉国
        case "si":
            return "LK" // 僧伽罗语 -> 斯里兰卡
        case "my":
            return "MM" // 缅甸语 -> 缅甸
        case "km":
            return "KH" // 高棉语 -> 柬埔寨
        case "lo":
            return "LA" // 老挝语 -> 老挝
        case "ne":
            return "NP" // 尼泊尔语 -> 尼泊尔
        case "ka":
            return "GE" // 格鲁吉亚语 -> 格鲁吉亚
        case "hy":
            return "AM" // 亚美尼亚语 -> 亚美尼亚
        case "az":
            return "AZ" // 阿塞拜疆语 -> 阿塞拜疆
        case "kk":
            return "KZ" // 哈萨克语 -> 哈萨克斯坦
        case "ky":
            return "KG" // 吉尔吉斯语 -> 吉尔吉斯斯坦
        case "uz":
            return "UZ" // 乌兹别克语 -> 乌兹别克斯坦
        case "tg":
            return "TJ" // 塔吉克语 -> 塔吉克斯坦
        case "mn":
            return "MN" // 蒙古语 -> 蒙古
        case "bo":
            return "CN" // 藏语 -> 中国
        case "ug":
            return "CN" // 维吾尔语 -> 中国
        case "en":
            return "US" // 英语 -> 美国
        default:
            return "US" // 默认美区
        }
    }
    
    // 当前地区显示名称 - 使用简体中文
    var currentRegionDisplayName: String {
        let regionCode = effectiveSearchRegion
        return SearchView.countryCodeMapChinese[regionCode] ?? SearchView.countryCodeMap[regionCode] ?? regionCode
    }
    
    // 当前地区详细信息
    var currentRegionInfo: String {
        let regionCode = effectiveSearchRegion
        let chineseName = SearchView.countryCodeMapChinese[regionCode] ?? ""
        let englishName = SearchView.countryCodeMap[regionCode] ?? ""
        
        if !chineseName.isEmpty && !englishName.isEmpty {
            return "\(chineseName) (\(englishName))"
        } else if !chineseName.isEmpty {
            return chineseName
        } else if !englishName.isEmpty {
            return englishName
        } else {
            return regionCode
        }
    }
    
    // 当前地区国旗
    var currentRegionFlag: String {
        flag(country: effectiveSearchRegion)
    }
    
    // 获取地区选择器的地区列表 - 优先显示登录账户地区
    var sortedRegionKeys: [String] {
        var regions = Array(SearchView.storeFrontCodeMap.keys)
        
        // 如果有登录账户，将其地区放在第一位
        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            if let index = regions.firstIndex(of: accountRegion) {
                regions.remove(at: index)
                regions.insert(accountRegion, at: 0)
            }
        }
        
        // 将常用地区放在前面 - 包含香港、澳门、台湾等中文地区
        let commonRegions = ["US", "CN", "HK", "MO", "TW", "JP", "KR", "GB", "DE", "FR", "CA", "AU", "IT", "ES", "NL", "SE", "NO", "DK", "FI", "RU", "BR", "MX", "IN", "SG", "TH", "VN", "MY", "ID", "PH"]
        
        for commonRegion in commonRegions.reversed() {
            if let index = regions.firstIndex(of: commonRegion) {
                regions.remove(at: index)
                regions.insert(commonRegion, at: 0)
            }
        }
        
        return regions
    }
    
    // Static country code to name mapping (English)
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
    
    // Static country code to name mapping (简体中文)
    static let countryCodeMapChinese: [String: String] = [
        "AE": "阿联酋", "AG": "安提瓜和巴布达", "AI": "安圭拉", "AL": "阿尔巴尼亚", "AM": "亚美尼亚",
        "AO": "安哥拉", "AR": "阿根廷", "AT": "奥地利", "AU": "澳大利亚", "AZ": "阿塞拜疆",
        "BB": "巴巴多斯", "BD": "孟加拉国", "BE": "比利时", "BG": "保加利亚", "BH": "巴林",
        "BM": "百慕大", "BN": "文莱", "BO": "玻利维亚", "BR": "巴西", "BS": "巴哈马",
        "BW": "博茨瓦纳", "BY": "白俄罗斯", "BZ": "伯利兹", "CA": "加拿大", "CH": "瑞士",
        "CI": "科特迪瓦", "CL": "智利", "CN": "中国", "CO": "哥伦比亚", "CR": "哥斯达黎加",
        "CY": "塞浦路斯", "CZ": "捷克", "DE": "德国", "DK": "丹麦", "DM": "多米尼克",
        "DO": "多米尼加", "DZ": "阿尔及利亚", "EC": "厄瓜多尔", "EE": "爱沙尼亚", "EG": "埃及",
        "ES": "西班牙", "FI": "芬兰", "FR": "法国", "GB": "英国", "GD": "格林纳达",
        "GE": "格鲁吉亚", "GH": "加纳", "GR": "希腊", "GT": "危地马拉", "GY": "圭亚那",
        "HK": "香港", "HN": "洪都拉斯", "HR": "克罗地亚", "HU": "匈牙利", "ID": "印度尼西亚",
        "IE": "爱尔兰", "IL": "以色列", "IN": "印度", "IS": "冰岛", "IT": "意大利",
        "JM": "牙买加", "JO": "约旦", "JP": "日本", "KE": "肯尼亚", "KN": "圣基茨和尼维斯",
        "KR": "韩国", "KW": "科威特", "KY": "开曼群岛", "KZ": "哈萨克斯坦", "LB": "黎巴嫩",
        "LC": "圣卢西亚", "LI": "列支敦士登", "LK": "斯里兰卡", "LT": "立陶宛", "LU": "卢森堡",
        "LV": "拉脱维亚", "MD": "摩尔多瓦", "MG": "马达加斯加", "MK": "北马其顿", "ML": "马里",
        "MN": "蒙古", "MO": "澳门", "MS": "蒙特塞拉特", "MT": "马耳他", "MU": "毛里求斯",
        "MV": "马尔代夫", "MX": "墨西哥", "MY": "马来西亚", "NE": "尼日尔", "NG": "尼日利亚",
        "NI": "尼加拉瓜", "NL": "荷兰", "NO": "挪威", "NP": "尼泊尔", "NZ": "新西兰",
        "OM": "阿曼", "PA": "巴拿马", "PE": "秘鲁", "PH": "菲律宾", "PK": "巴基斯坦",
        "PL": "波兰", "PT": "葡萄牙", "PY": "巴拉圭", "QA": "卡塔尔", "RO": "罗马尼亚",
        "RS": "塞尔维亚", "RU": "俄罗斯", "SA": "沙特阿拉伯", "SE": "瑞典", "SG": "新加坡",
        "SI": "斯洛文尼亚", "SK": "斯洛伐克", "SN": "塞内加尔", "SR": "苏里南", "SV": "萨尔瓦多",
        "TC": "特克斯和凯科斯群岛", "TH": "泰国", "TN": "突尼斯", "TR": "土耳其", "TT": "特立尼达和多巴哥",
        "TW": "台湾", "TZ": "坦桑尼亚", "UA": "乌克兰", "UG": "乌干达", "US": "美国",
        "UY": "乌拉圭", "UZ": "乌兹别克斯坦", "VC": "圣文森特和格林纳丁斯", "VE": "委内瑞拉",
        "VG": "英属维尔京群岛", "VN": "越南", "YE": "也门", "ZA": "南非"
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
    
    // 使用排序后的地区列表
    var regionKeys: [String] { sortedRegionKeys }
    
    // 根据搜索输入过滤地区列表
    var filteredRegionKeys: [String] {
        if searchInput.isEmpty {
            return regionKeys
        } else {
            return regionKeys.filter { regionCode in
                let chineseName = SearchView.countryCodeMapChinese[regionCode] ?? ""
                let englishName = SearchView.countryCodeMap[regionCode] ?? ""
                let searchText = searchInput.lowercased()
                
                return regionCode.lowercased().contains(searchText) ||
                       chineseName.lowercased().contains(searchText) ||
                       englishName.lowercased().contains(searchText)
            }
        }
    }
    
    @State var searchInput: String = ""
    @State var searchResult: [iTunesSearchResult] = []
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    private let pageSize = 20
    @State var searchHistory: [String] = []
    @State var showSearchHistory = false
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
    @State var showVersionPicker = false
    @State var selectedApp: iTunesSearchResult?
    @State var availableVersions: [StoreAppVersion] = []
    @State var isLoadingVersions = false
    @State var versionError: String?
    var possibleReigon: Set<String> {
        vm.selectedAccount != nil ? Set([vm.selectedAccount!.countryCode]) : Set()
    }
    var body: some SwiftUI.View {
        NavigationView {
            ZStack {
                // 统一背景色 - 与其他界面保持一致
                Color(.systemBackground)
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
                                // 账户状态栏
                                accountStatusBar
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateHeader)
                                
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
            print("[SearchView] 视图加载完成，开始初始化")
            
            // 智能地区检测 - 确保在UI加载后执行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("[SearchView] 执行智能地区检测")
                detectAndSetRegion()
                
                // 打印最终状态
                print("[SearchView] 初始化完成 - 最终状态:")
                print("  - searchRegion: \(searchRegion)")
                print("  - effectiveSearchRegion: \(effectiveSearchRegion)")
                if let account = appStore.selectedAccount {
                    print("  - 登录账户: \(account.email), 地区: \(account.countryCode)")
                } else {
                    print("  - 未登录账户")
                }
                
                // 触发UI刷新
                self.uiRefreshTrigger = UUID()
            }
            
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
        .onReceive(appStore.$selectedAccount) { account in
            // 监听账户变化，自动更新搜索地区
            if let newAccount = account {
                print("[SearchView] 检测到账户变化: \(newAccount.email), 地区: \(newAccount.countryCode)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detectAndSetRegion()
                    // 强制刷新UI - 使用状态变量触发刷新
                    DispatchQueue.main.async {
                        self.uiRefreshTrigger = UUID()
                    }
                }
            } else {
                print("[SearchView] 账户已登出，重置为默认地区")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detectAndSetRegion()
                }
            }
        }
        .sheet(isPresented: $showVersionPicker) {
            versionPickerSheet
        }
        .sheet(isPresented: $showRegionPicker) {
            regionPickerSheet
        }
        .sheet(isPresented: $showLoginSheet) {
            AddAccountView()
                .environmentObject(appStore)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showAccountMenu) {
            accountMenuSheet
        }
    }
    
    // MARK: - 智能地区检测
    private func detectAndSetRegion() {
        // 优先使用账户地区（如果有登录）
        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            print("[SearchView] 检测到登录账户: \(currentAccount.email), 地区代码: \(accountRegion)")
            
            // 确保账户地区被正确设置，不依赖其他计算属性
            if searchRegion != accountRegion && !isUserSelectedRegion {
                searchRegion = accountRegion
                print("[SearchView] 已将搜索地区更新为账户地区: \(searchRegion)")
            }
        } else {
            // 如果没有登录账户，使用系统语言检测或默认地区
            let detectedRegion = effectiveSearchRegion
            if searchRegion != detectedRegion && !isUserSelectedRegion {
                searchRegion = detectedRegion
                print("[SearchView] 未检测到登录账户，使用默认地区: \(searchRegion)")
            }
        }
        
        print("[SearchView] 当前显示地区: \(effectiveSearchRegion), 用户手动选择标志: \(isUserSelectedRegion)")
        
        // 强制更新UI - 使用状态变量触发刷新
        DispatchQueue.main.async {
            self.uiRefreshTrigger = UUID()
        }
    }
    
    // MARK: - 现代化搜索栏
    var modernSearchBar: some SwiftUI.View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                // 搜索输入框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(searchKeyFocused ? themeManager.accentColor : (themeManager.selectedTheme == .dark ? .secondary : .secondary))
                    TextField("搜索应用、游戏和更多内容...", text: $searchKey)
                        .font(.title3)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                        .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            searchKeyFocused ? .blue : Color.clear,
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
            // 搜索类型、下载按钮和地区选择
            HStack(spacing: 16) {
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
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14, weight: .medium))
                        Text(searchType.displayName)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(themeManager.accentColor.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // 智能地区选择器
                smartRegionSelector
            }
        }
    }
    
    // MARK: - 智能地区选择器
    var smartRegionSelector: some SwiftUI.View {
        Button(action: {
            showRegionPicker = true
        }) {
            HStack(spacing: 8) {
                Text(flag(country: effectiveSearchRegion))
                    .font(.title2)
                Text(SearchView.countryCodeMapChinese[effectiveSearchRegion] ?? SearchView.countryCodeMap[effectiveSearchRegion] ?? effectiveSearchRegion)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                // 显示地区来源指示器
                if let currentAccount = appStore.selectedAccount {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .help("来自登录账户: \(currentAccount.email)")
                } else if !searchRegion.isEmpty {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .help("用户手动选择")
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                        .help("默认美区")
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                    .overlay(
                        Capsule()
                            .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .id("RegionSelector-\(effectiveSearchRegion)-\(uiRefreshTrigger)") // 强制刷新
        .onAppear {
            // 确保地区选择器显示正确的当前地区
            print("[SearchView] 地区选择器显示，当前地区: \(effectiveSearchRegion)")
        }
    }
    
    // MARK: - 地区选择器弹窗
    var regionPickerSheet: some SwiftUI.View {
        NavigationView {
            VStack(spacing: 0) {
                // 当前地区信息
                VStack(spacing: 16) {
                    Text("当前搜索地区")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                                        HStack(spacing: 16) {
                        Text(flag(country: searchRegion.isEmpty ? effectiveSearchRegion : searchRegion))
                            .font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 8) {
                            let displayRegion = searchRegion.isEmpty ? effectiveSearchRegion : searchRegion
                            Text(SearchView.countryCodeMapChinese[displayRegion] ?? SearchView.countryCodeMap[displayRegion] ?? displayRegion)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(currentRegionInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("地区代码: \(displayRegion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // 显示地区来源
                            if isUserSelectedRegion && !searchRegion.isEmpty {
                                Text("用户手动选择")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else if let currentAccount = appStore.selectedAccount {
                                Text("来自登录账户: \(currentAccount.email)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("默认美区")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                    )
                }
                .padding()
                
                // 地区统计信息
                HStack {
                    Text("共 \(regionKeys.count) 个地区")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let currentAccount = appStore.selectedAccount {
                        Text("登录账户: \(currentAccount.countryCode)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // 地区搜索框 - 统一大小和样式
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("搜索地区...", text: $searchInput)
                        .font(.title3)
                        .onChange(of: searchInput) { newValue in
                            // 实时搜索地区
                            if newValue.isEmpty {
                                // 如果搜索框为空，显示所有地区
                            }
                        }
                    if !searchInput.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchInput = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                        .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            .clear,
                            lineWidth: 2
                        )
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // 地区选择列表
                List {
                    ForEach(filteredRegionKeys, id: \.self) { regionCode in
                        Button(action: {
                            selectRegion(regionCode)
                        }) {
                            HStack(spacing: 16) {
                                Text(flag(country: regionCode))
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(SearchView.countryCodeMapChinese[regionCode] ?? SearchView.countryCodeMap[regionCode] ?? regionCode)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                    Text(regionCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if regionCode == searchRegion {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.accentColor)
                                        .font(.system(size: 16, weight: .bold))
                                }
                                
                                // 显示地区来源标识
                                if isUserSelectedRegion && regionCode == searchRegion {
                                    Image(systemName: "hand.point.up.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                        .help("用户手动选择")
                                } else if let currentAccount = appStore.selectedAccount, regionCode == currentAccount.countryCode {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .help("登录账户地区")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择搜索地区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("返回") {
                        showRegionPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - 账户状态栏
    var accountStatusBar: some SwiftUI.View {
        VStack(spacing: 0) {
            if let currentAccount = appStore.selectedAccount {
                // 已登录状态
                HStack(spacing: 16) {
                    // 账户头像
                    Button(action: {
                        showAccountMenu = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentAccount.email)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    Text(flag(country: currentAccount.countryCode))
                                        .font(.caption)
                                    Text(SearchView.countryCodeMapChinese[currentAccount.countryCode] ?? SearchView.countryCodeMap[currentAccount.countryCode] ?? currentAccount.countryCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // 登出按钮
                    Button(action: {
                        logoutAccount()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.caption)
                            Text("登出")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            } else {
                // 未登录状态
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未登录")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("登录以获得更好的体验")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 登录按钮
                    Button(action: {
                        showLoginSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .font(.caption)
                            Text("登录")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - 地区选择处理
    private func selectRegion(_ regionCode: String) {
        searchRegion = regionCode
        isUserSelectedRegion = true // 设置用户手动选择标志
        print("[SearchView] 用户选择地区: \(regionCode)")
        
        // 强制更新UI - 使用状态变量触发刷新
        DispatchQueue.main.async {
            self.uiRefreshTrigger = UUID()
        }
        
        // 如果当前有搜索结果，清空并重新搜索
        if !searchResult.isEmpty {
            searchResult = []
            Task {
                await performSearch()
            }
        }
        
        showRegionPicker = false
        
        // 打印调试信息
        print("[SearchView] 地区选择完成，当前搜索地区: \(searchRegion)")
        print("[SearchView] 用户手动选择标志: \(isUserSelectedRegion)")
        print("[SearchView] effectiveSearchRegion: \(effectiveSearchRegion)")
    }
    // MARK: - 搜索历史区域
    var searchHistorySection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("最近搜索", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除全部") {
                    withAnimation(.easeInOut) {
                        clearSearchHistory()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchHistory.prefix(8), id: \.self) { history in
                        Button {
                            searchKey = history
                            showSearchHistory = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(history)
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        Capsule()
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 24)
    }
    // MARK: - 搜索建议区域
    var searchSuggestionsSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("搜索建议")
                    .font(.title3)
                Spacer()
                Button("关闭") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchSuggestions = false
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .foregroundColor(.blue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchSuggestions.prefix(8), id: \.self) { suggestion in
                        Button {
                            searchKey = suggestion
                            showSearchSuggestions = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(suggestion)
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        Capsule()
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 24)
    }
    // MARK: - 分类选择器
    var categorySelector: some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }
    // MARK: - 搜索结果区域
    var searchResultsSection: some SwiftUI.View {
        VStack(spacing: 24) {
            if !searchResult.isEmpty {
                // 结果统计和视图切换器
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("找到 \(searchResult.count) 个结果")
                            .font(.title2)
                            .foregroundColor(.primary)
                        if !searchInput.isEmpty {
                            Text("关于 \"\(searchInput)\"")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // 视图模式切换器
                    viewModeToggle
                }
                .padding(.horizontal, 24)
            }
            // 搜索结果网格/列表
            if let error = searchError {
                AnyView(searchErrorView(error: error))
            } else if searching {
                AnyView(searchingIndicator)
            } else if searchResult.isEmpty {
                AnyView(emptyStateView)
            } else {
                AnyView(searchResultsGrid
                    .id("searchResultsGrid-\(viewMode.rawValue)-\(viewModeRefreshTrigger)")) // 添加ID确保视图刷新
            }
        }
    }
    // MARK: - 搜索中指示器
    var searchingIndicator: some SwiftUI.View {
        VStack(spacing: 24) {
            // 动画加载指示器
            ZStack {
                Circle()
                    .stroke(.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .gray],
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
            VStack(spacing: 8) {
                Text("正在搜索...")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text("为您寻找最佳结果")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    // MARK: - 空状态视图
    var emptyStateView: some SwiftUI.View {
        VStack(spacing: 24) {
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
            VStack(spacing: 8) {
                Text("APP降级")
                    .font(.title)
                    .foregroundColor(.primary)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // 推荐搜索
            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索历史")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(searchHistory.prefix(3), id: \.self) { history in
                            Button {
                                searchKey = history
                                Task {
                                    await performSearch()
                                }
                            } label: {
                                Text(history)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
    // MARK: - 搜索错误视图
    func searchErrorView(error: String) -> any SwiftUI.View {
        VStack(spacing: 24) {
            // 错误图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.1), .red.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.red.opacity(0.8))
            }
            VStack(spacing: 8) {
                Text("搜索出现问题")
                    .font(.title)
                    .foregroundColor(.primary)
                Text(error)
                    .font(.body)
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
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("重试")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    
    // MARK: - 视图模式切换器
    var viewModeToggle: some SwiftUI.View {
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
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(mode.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(viewMode == mode ? .white : themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewMode == mode ? themeManager.accentColor : themeManager.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    // MARK: - 搜索结果网格
    var searchResultsGrid: some SwiftUI.View {
        Group {
            if viewMode == .card {
                // 卡片视图 - 网格布局
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(searchResult.indices, id: \.self) { index in
                        let item = searchResult[index]
                        AnyView(resultCardView(item: item, index: index))
                    }
                }
                .padding(.horizontal, 24)
                .onAppear {
                    print("[SearchView] 显示卡片视图，结果数量: \(searchResult.count)")
                }
            } else {
                // 列表视图
                LazyVStack(spacing: 16) {
                    ForEach(searchResult.indices, id: \.self) { index in
                        let item = searchResult[index]
                        AnyView(resultListView(item: item, index: index))
                    }
                }
                .padding(.horizontal, 24)
                .onAppear {
                    print("[SearchView] 显示列表视图，结果数量: \(searchResult.count)")
                }
            }
            // 加载更多指示器
            if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载更多...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
            }
        }
    }
    // MARK: - 结果卡片视图
    func resultCardView(item: iTunesSearchResult, index: Int) -> any SwiftUI.View {
        Button {
            // 只调用loadVersionsForApp，让它统一管理状态设置
            Task {
                await loadVersionsForApp(item)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 应用图标
                AsyncImage(url: URL(string: item.artworkUrl512 ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                // 应用信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.artistName ?? "未知开发者")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                // 价格和版本信息
                HStack(spacing: 8) {
                    if let price = item.formattedPrice {
                        Text(price)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeManager.accentColor)
                            )
                    }
                    Text("v\(item.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.secondarySystemBackground))
                        )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
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
    func resultListView(item: iTunesSearchResult, index: Int) -> any SwiftUI.View {
        Button {
            // 只调用loadVersionsForApp，让它统一管理状态设置
            Task {
                await loadVersionsForApp(item)
            }
        } label: {
            HStack(spacing: 16) {
                // 应用图标
                AsyncImage(url: URL(string: item.artworkUrl512 ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // 应用信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.artistName ?? "未知开发者")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let price = item.formattedPrice {
                            Text(price)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        Text("v\(item.version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
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
        
        // 使用智能检测的地区
        let regionToUse = effectiveSearchRegion
        print("[SearchView] 执行搜索，使用地区: \(regionToUse)")
        
        withAnimation(.easeInOut) {
            searching = true
            searchResult = []
            currentPage = 1
            searchError = nil
        }
        addToSearchHistory(searchKey)
        showSearchHistory = false
        let cacheKey = "\(searchKey)_\(searchType.rawValue)_\(regionToUse)"
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
            let response = try await iTunesClient.shared.search(
                term: searchKey,
                limit: pageSize,
                countryCode: regionToUse,
                deviceFamily: searchType
            )
            let results = response ?? []
            await MainActor.run {
                withAnimation(.spring()) {
                    searchResult = results
                    searching = false
                    searchCache[cacheKey] = results
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
                // 使用智能检测的地区
                let regionToUse = effectiveSearchRegion
                let response = try await iTunesClient.shared.search(
                    term: searchKey,
                    limit: pageSize,
                    countryCode: regionToUse,
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
            let appName = result.name
            if !appName.isEmpty {
                suggestions.insert(appName)
            }
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
    var versionPickerSheet: some SwiftUI.View {
        NavigationView {
            ZStack {
                // 现代化背景渐变
                LinearGradient(
                    colors: themeManager.selectedTheme == .dark ? 
                        [Color(.systemBackground), Color(.secondarySystemBackground)] :
                        [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 版本列表区域 - 直接显示，移除应用头部
                VStack {
                    if isLoadingVersions {
                        loadingVersionsView
                    } else if let error = versionError {
                        AnyView(errorView(error: error))
                    } else if availableVersions.isEmpty {
                        emptyVersionsView
                    } else {
                        versionsListView
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.selectedTheme == .dark ? 
                              Color(.secondarySystemBackground).opacity(0.5) : 
                              Color.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
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


    var loadingVersionsView: some SwiftUI.View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载历史版本...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    func errorView(error: String) -> some SwiftUI.View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                if let app = selectedApp {
                    loadVersionsForApp(app)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    var emptyVersionsView: some SwiftUI.View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无历史版本")
                .font(.title2)
                .fontWeight(.semibold)
            Text("该应用暂时没有可用的历史版本")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var versionsListView: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 应用名称标题
                VStack(spacing: 8) {
                    Text(selectedApp?.trackName ?? "APP")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(selectedApp?.artistName ?? "Unknown Developer")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // 版本数量统计
                HStack {
                    Text("历史版本")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(availableVersions.count) 个版本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // 版本列表
                ForEach(availableVersions, id: \.versionId) {
                    AnyView(createModernVersionRow(version: $0))
                }
            }
            .padding(.bottom, 24)
        }
    }
    private func createModernVersionRow(version: StoreAppVersion) -> any SwiftUI.View {
        HStack(spacing: 16) {
            // 版本信息区域
            VStack(alignment: .leading, spacing: 8) {
                // 版本号
                HStack(spacing: 8) {
                    Text("版本 \(version.versionString)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                
                // 版本ID
                HStack(spacing: 8) {
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
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                    Text("下载")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.selectedTheme == .dark ? 
                      Color(.secondarySystemBackground).opacity(0.3) : 
                      Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .padding(.horizontal, 24)
    }
    @MainActor
    func downloadVersion(app: iTunesSearchResult, version: StoreAppVersion) async {
        showVersionPicker = false
        guard appStore.selectedAccount != nil else {
            print("[SearchView] 错误：没有登录账户")
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
    
    
    // MARK: - 账户菜单弹窗
    var accountMenuSheet: some SwiftUI.View {
        NavigationView {
            if let account = appStore.selectedAccount {
                AccountDetailView(account: account)
                    .environmentObject(themeManager)
                    .environmentObject(appStore)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("未登录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("请先登录账户")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("登录账户") {
                        showAccountMenu = false
                        showLoginSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: themeManager.selectedTheme == .dark ? 
                            [Color(.systemBackground), Color(.secondarySystemBackground)] :
                            [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("账户信息")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") {
                            showAccountMenu = false
                        }
                        .foregroundColor(themeManager.accentColor)
                        .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - 登录/登出功能
    private func logoutAccount() {
        print("[SearchView] 用户登出")
        appStore.logoutAccount()
        
        // 强制刷新UI
        DispatchQueue.main.async {
            self.uiRefreshTrigger = UUID()
        }
    }
}
