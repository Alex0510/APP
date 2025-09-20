//
//  AccountManagerView.swift
//
//  Created by pxx917144686 on 2025/08/20.
//

import SwiftUI

struct AccountManagerView: View {
    @EnvironmentObject var appStore: AppStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAddAccount = false
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: Account?
    @State private var refreshingAccount: Account?
    @State private var showingLoginSheet = false
    
    var body: some View {
        accountList
    }
    
    private var accountList: some View {
        List {
            accountsSection
            addAccountSection
        }
        .navigationTitle("账户管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
                .environmentObject(appStore)
        }
        .sheet(isPresented: $showingLoginSheet) {
            AddAccountView()
                .environmentObject(appStore)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let account = accountToDelete {
                    logoutAccount(account)
                    accountToDelete = nil
                }
            }
        } message: {
            if let account = accountToDelete {
                Text("确定要删除账户 \(account.email) 吗？此操作无法撤销。")
            }
        }
    }
    
    private var accountsSection: some View {
        Section(header: Text("已登录的账户")) {
            if appStore.accounts.isEmpty {
                emptyAccountsView
            } else {
                ForEach(appStore.accounts) { account in
                    accountRow(for: account)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                accountToDelete = account
                                showingDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            
                            Button {
                                appStore.switchAccount(to: account)
                            } label: {
                                Label("切换", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
    }
    
    private var addAccountSection: some View {
        Section {
            Button(action: {
                showingLoginSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加新账户")
                }
            }
        }
    }
    
    private var emptyAccountsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("暂无账户")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("点击下方按钮添加第一个账户")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }
    
    private func accountRow(for account: Account) -> some View {
        ManagerAccountRowView(
            account: account,
            isSelected: appStore.selectedAccount?.id == account.id,
            onRefresh: {
                refreshingAccount = account
                Task {
                    do {
                        try await appStore.refreshAccountTokens(for: account)
                        refreshingAccount = nil
                    } catch {
                        print("刷新账户失败: \(error)")
                        refreshingAccount = nil
                    }
                }
            },
            onDelete: {
                accountToDelete = account
                showingDeleteAlert = true
            },
            onSwitch: {
                appStore.switchAccount(to: account)
            }
        )
    }
    
    // MARK: - 账户操作方法
    
    private func logoutAccount(_ account: Account) {
        print("[AccountManagerView] 登出账户: \(account.email)")
        appStore.deleteAccount(account)
    }
}

// 修复：重命名结构体以避免重复声明
struct ManagerAccountRowView: View {
    let account: Account
    let isSelected: Bool
    let onRefresh: () -> Void
    let onDelete: () -> Void
    let onSwitch: () -> Void // 添加切换回调
    
    @State private var isRefreshing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 账户头像
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            
            // 账户信息
            VStack(alignment: .leading, spacing: 4) {
                // 显示账户名称，如果名称与邮箱相同或为空，则不显示名称行
                if !account.name.isEmpty && account.name != account.email {
                    Text(account.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                // 显示邮箱
                Text(account.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 显示地区代码 - 使用账户的实际地区代码
                    let regionDisplay = getRegionDisplay(for: account.countryCode)
                    Text(regionDisplay)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.8))
                        )
                    
                    if isSelected {
                        Text("当前账户")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 切换账户按钮 - 只有当不是当前账户时才显示
                if !isSelected {
                    Button(action: {
                        onSwitch()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: {
                    isRefreshing = true
                    onRefresh()
                    // 2秒后重置刷新状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRefreshing = false
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRefreshing)
                
                if !isSelected {
                    Button(action: {
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // 使整个行可点击
        .onTapGesture {
            if !isSelected {
                onSwitch()
            }
        }
    }
    
    // MARK: - 辅助方法
    private func getRegionDisplay(for countryCode: String) -> String {
        // 地区代码映射
        let regionMap: [String: String] = [
            "US": "美国", "CN": "中国", "JP": "日本", "GB": "英国",
            "DE": "德国", "FR": "法国", "AU": "澳大利亚", "CA": "加拿大",
            "IT": "意大利", "ES": "西班牙", "KR": "韩国", "BR": "巴西",
            "MX": "墨西哥", "IN": "印度", "RU": "俄罗斯", "NL": "荷兰",
            "SE": "瑞典", "NO": "挪威", "DK": "丹麦", "FI": "芬兰",
            "CH": "瑞士", "AT": "奥地利", "BE": "比利时", "IE": "爱尔兰",
            "PT": "葡萄牙", "GR": "希腊", "PL": "波兰", "CZ": "捷克",
            "HU": "匈牙利", "RO": "罗马尼亚", "SG": "新加坡", "TH": "泰国",
            "VN": "越南", "MY": "马来西亚", "ID": "印尼", "PH": "菲律宾",
            "TW": "台湾", "HK": "香港", "MO": "澳门",
            "AE": "阿联酋", "SA": "沙特", "TR": "土耳其", "ZA": "南非"
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


// 添加一个账户状态指示器视图，可以在主页面显示
struct AccountStatusIndicator: View {
    @EnvironmentObject var appStore: AppStore
    
    var body: some View {
        HStack(spacing: 8) {
            if let account = appStore.selectedAccount {
                // 显示已登录状态
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text(account.email)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                // 显示未登录状态
                Image(systemName: "person.circle")
                    .foregroundColor(.gray)
                Text("未登录")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
