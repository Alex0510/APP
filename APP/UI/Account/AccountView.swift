//
//  AccountView.swift
//
//  Created by pxx917144686 on 2025/08/20.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AccountView: View {
    @State var addSheet = false
    @State var animation = false
    @EnvironmentObject var appStore: AppStore
    @State var layoutRefreshTrigger = UUID()
    @State var showDeleteAlert = false
    @State var accountToDelete: Account?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部安全区域占位 - 真机适配
                GeometryReader { geometry in
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44)
                        .onAppear {
                            print("[AccountView] 顶部安全区域: \(geometry.safeAreaInsets.top)")
                        }
                }
                .frame(height: 44) // 固定高度，避免布局跳动
                
                // 主要内容
                VStack(spacing: 0) {
                    if appStore.accounts.isEmpty {
                        VStack(spacing: 30) {
                            Spacer()
                            VStack(spacing: 20) {
                                // Logo with Animation - 修复动画问题
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.blue)
                                    .scaleEffect(animation ? 1.05 : 1.0) // 减少动画幅度
                                    .opacity(animation ? 0.9 : 0.7) // 减少透明度变化
                                    .animation(
                                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), // 减少动画时长
                                        value: animation
                                    )
                                // Welcome Text
                                VStack(spacing: 12) {
                                    Text("Apple ID")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("遇到问题,联系pxx917144686")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            // Add Account Button
                            Button(action: { addSheet.toggle() }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.body)
                                    Text("添加账户")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            // 调试按钮 - 强制刷新布局
                            #if DEBUG
                            Button(action: {
                                print("[AccountView] 手动强制刷新")
                                layoutRefreshTrigger = UUID()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.body)
                                    Text("刷新布局")
                                }
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            #endif
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                    } else {
                        // 显示账户列表
                        List {
                            ForEach(appStore.accounts) { account in
                                NavigationLink(destination: AccountDetailView(account: account)) {
                                    AccountRowView(account: account)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onDelete(perform: deleteAccount) // 保留滑动删除功能
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .background(Color(.systemBackground))
                .padding(.top, 10) // 添加额外的顶部间距
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true) // 隐藏返回按钮
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Apple ID")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appStore.accounts.isEmpty {
                        Button(action: { addSheet.toggle() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $addSheet) {
                AddAccountView()
                    .environmentObject(AppStore.this)
            }
            .onAppear {
                // 强制刷新布局
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    layoutRefreshTrigger = UUID()
                    print("[AccountView] 强制刷新布局")
                }
                
                // 启动动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        animation = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in
                // 接收强制刷新通知 - 真机适配
                print("[AccountView] 接收到强制刷新通知")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    layoutRefreshTrigger = UUID()
                    print("[AccountView] 真机适配强制刷新完成")
                }
            }
        }
        .navigationViewStyle(.stack)
        .background(Color(.systemBackground)) // 确保整个视图有背景色
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let account = accountToDelete {
                    print("[AccountView] 用户确认删除账户: \(account.email)")
                    // 执行删除操作
                    appStore.delete(id: account.id)
                    print("[AccountView] 删除完成，当前账户数量: \(appStore.accounts.count)")
                    
                    // 强制刷新UI
                    DispatchQueue.main.async {
                        layoutRefreshTrigger = UUID()
                    }
                    
                    // 清理状态
                    accountToDelete = nil
                }
            }
        } message: {
            if let account = accountToDelete {
                Text("确定要删除账户 \(account.email) 吗？此操作无法撤销。")
            }
        }
    }
    
    private func deleteAccount(offsets: IndexSet) {
        print("[AccountView] 删除账户被调用，索引: \(offsets)")
        
        for index in offsets {
            let account = appStore.accounts[index]
            print("[AccountView] 准备删除账户: \(account.email), ID: \(account.id)")
            
            // 设置要删除的账户并显示确认对话框
            accountToDelete = account
            showDeleteAlert = true
        }
    }
}

// MARK: - Account Row View
struct AccountRowView: View {
    let account: Any
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // 账户头像
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.blue)
            
            // 账户信息
            VStack(alignment: .leading, spacing: 6) { // 增加间距
                if let account = account as? Account {
                    Text(account.email)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !account.name.isEmpty {
                        Text(account.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2) // 允许两行显示
                    }
                    
                    HStack(spacing: 8) {
                        // 显示地区代码，使用更友好的显示方式
                        let regionDisplay = getRegionDisplay(for: account.countryCode)
                        Text(regionDisplay)
                            .font(.caption)
                            .foregroundColor(.white) // 改为白色以提高可读性
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4) // 增加垂直间距
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.8)) // 使用更明显的颜色
                            )
                        
                        if !account.dsPersonId.isEmpty {
                            Text("DS: \(account.dsPersonId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                    }
                } else {
                    // 如果无法转换为Account类型，显示默认信息
                    Text("账户信息")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("无法加载详细信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12) // 增加垂直间距
        .padding(.horizontal, 4) // 添加水平间距
        .background(Color(.systemBackground)) // 确保有背景色
    }
    
    // MARK: - 辅助方法
    private func getRegionDisplay(for countryCode: String) -> String {
        // 地区代码映射 - 完整版本（去重）
        let regionMap: [String: String] = [
            // 北美
            "US": "美国",
            "CA": "加拿大",
            "MX": "墨西哥",
            
            // 欧洲
            "GB": "英国",
            "DE": "德国",
            "FR": "法国",
            "IT": "意大利",
            "ES": "西班牙",
            "NL": "荷兰",
            "SE": "瑞典",
            "NO": "挪威",
            "DK": "丹麦",
            "FI": "芬兰",
            "CH": "瑞士",
            "AT": "奥地利",
            "BE": "比利时",
            "IE": "爱尔兰",
            "PT": "葡萄牙",
            "GR": "希腊",
            "PL": "波兰",
            "CZ": "捷克",
            "HU": "匈牙利",
            "RO": "罗马尼亚",
            "BG": "保加利亚",
            "HR": "克罗地亚",
            "SI": "斯洛文尼亚",
            "SK": "斯洛伐克",
            "LT": "立陶宛",
            "LV": "拉脱维亚",
            "EE": "爱沙尼亚",
            "LU": "卢森堡",
            "MT": "马耳他",
            "CY": "塞浦路斯",
            "IS": "冰岛",
            "LI": "列支敦士登",
            "MC": "摩纳哥",
            "AD": "安道尔",
            "SM": "圣马力诺",
            "VA": "梵蒂冈",
            
            // 亚洲
            "CN": "中国",
            "HK": "香港",
            "MO": "澳门",
            "TW": "台湾",
            "JP": "日本",
            "KR": "韩国",
            "SG": "新加坡",
            "TH": "泰国",
            "VN": "越南",
            "MY": "马来西亚",
            "ID": "印尼",
            "PH": "菲律宾",
            "IN": "印度",
            "PK": "巴基斯坦",
            "BD": "孟加拉国",
            "LK": "斯里兰卡",
            "NP": "尼泊尔",
            "MM": "缅甸",
            "KH": "柬埔寨",
            "LA": "老挝",
            "BN": "文莱",
            "TL": "东帝汶",
            "MN": "蒙古",
            "KZ": "哈萨克斯坦",
            "UZ": "乌兹别克斯坦",
            "KG": "吉尔吉斯斯坦",
            "TJ": "塔吉克斯坦",
            "TM": "土库曼斯坦",
            "AF": "阿富汗",
            "IR": "伊朗",
            "IQ": "伊拉克",
            "SA": "沙特阿拉伯",
            "AE": "阿联酋",
            "QA": "卡塔尔",
            "KW": "科威特",
            "BH": "巴林",
            "OM": "阿曼",
            "YE": "也门",
            "JO": "约旦",
            "LB": "黎巴嫩",
            "SY": "叙利亚",
            "IL": "以色列",
            "PS": "巴勒斯坦",
            "TR": "土耳其",
            "GE": "格鲁吉亚",
            "AM": "亚美尼亚",
            "AZ": "阿塞拜疆",
            
            // 大洋洲
            "AU": "澳大利亚",
            "NZ": "新西兰",
            "FJ": "斐济",
            "PG": "巴布亚新几内亚",
            "NC": "新喀里多尼亚",
            "PF": "法属波利尼西亚",
            "VU": "瓦努阿图",
            "SB": "所罗门群岛",
            "TO": "汤加",
            "WS": "萨摩亚",
            "KI": "基里巴斯",
            "TV": "图瓦卢",
            "NR": "瑙鲁",
            "PW": "帕劳",
            "MH": "马绍尔群岛",
            "FM": "密克罗尼西亚",
            "CK": "库克群岛",
            "NU": "纽埃",
            "TK": "托克劳",
            
            // 南美
            "BR": "巴西",
            "AR": "阿根廷",
            "CL": "智利",
            "CO": "哥伦比亚",
            "PE": "秘鲁",
            "VE": "委内瑞拉",
            "EC": "厄瓜多尔",
            "BO": "玻利维亚",
            "PY": "巴拉圭",
            "UY": "乌拉圭",
            "GY": "圭亚那",
            "SR": "苏里南",
            "FK": "福克兰群岛",
            "GF": "法属圭亚那",
            
            // 非洲
            "ZA": "南非",
            "EG": "埃及",
            "NG": "尼日利亚",
            "KE": "肯尼亚",
            "ET": "埃塞俄比亚",
            "TZ": "坦桑尼亚",
            "UG": "乌干达",
            "GH": "加纳",
            "CI": "科特迪瓦",
            "SN": "塞内加尔",
            "ML": "马里",
            "BF": "布基纳法索",
            "NE": "尼日尔",
            "TD": "乍得",
            "SD": "苏丹",
            "SS": "南苏丹",
            "CF": "中非共和国",
            "CM": "喀麦隆",
            "GQ": "赤道几内亚",
            "GA": "加蓬",
            "CG": "刚果共和国",
            "CD": "刚果民主共和国",
            "AO": "安哥拉",
            "ZM": "赞比亚",
            "ZW": "津巴布韦",
            "BW": "博茨瓦纳",
            "NA": "纳米比亚",
            "SZ": "斯威士兰",
            "LS": "莱索托",
            "MG": "马达加斯加",
            "MU": "毛里求斯",
            "SC": "塞舌尔",
            "KM": "科摩罗",
            "DJ": "吉布提",
            "SO": "索马里",
            "ER": "厄立特里亚",
            "LY": "利比亚",
            "TN": "突尼斯",
            "DZ": "阿尔及利亚",
            "MA": "摩洛哥",
            "EH": "西撒哈拉",
            "MR": "毛里塔尼亚",
            
            // 中美洲和加勒比海
            "GT": "危地马拉",
            "BZ": "伯利兹",
            "SV": "萨尔瓦多",
            "HN": "洪都拉斯",
            "NI": "尼加拉瓜",
            "CR": "哥斯达黎加",
            "PA": "巴拿马",
            "CU": "古巴",
            "JM": "牙买加",
            "HT": "海地",
            "DO": "多米尼加",
            "PR": "波多黎各",
            "TT": "特立尼达和多巴哥",
            "BB": "巴巴多斯",
            "GD": "格林纳达",
            "LC": "圣卢西亚",
            "VC": "圣文森特和格林纳丁斯",
            "AG": "安提瓜和巴布达",
            "KN": "圣基茨和尼维斯",
            "DM": "多米尼克",
            "BS": "巴哈马",
            "TC": "特克斯和凯科斯群岛",
            "KY": "开曼群岛",
            "BM": "百慕大",
            "AW": "阿鲁巴",
            "CW": "库拉索",
            "SX": "圣马丁",
            "MF": "法属圣马丁",
            "BL": "圣巴泰勒米",
            "GP": "瓜德罗普",
            "MQ": "马提尼克",
            "RE": "留尼汪",
            "YT": "马约特",
            "WF": "瓦利斯和富图纳",
            "TF": "法属南部领地",
            "PM": "圣皮埃尔和密克隆",
            "GL": "格陵兰",
            "FO": "法罗群岛",
            "AX": "奥兰群岛",
            "SJ": "斯瓦尔巴和扬马延",
            "BV": "布韦岛",
            "GS": "南乔治亚和南桑威奇群岛",
            "IO": "英属印度洋领地",
            "SH": "圣赫勒拿",
            "GI": "直布罗陀"
        ]
        
        // 如果找到对应的中文名称，返回"中文名 (代码)"格式
        if let chineseName = regionMap[countryCode] {
            return "\(chineseName) (\(countryCode))"
        } else {
            // 如果没有找到，只返回代码
            return countryCode
        }
    }
}