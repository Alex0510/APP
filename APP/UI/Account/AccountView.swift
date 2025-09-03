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
    let account: Account
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
                    Text(account.countryCode)
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
            }
            
            Spacer()
            
            // 箭头指示器
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12) // 增加垂直间距
        .padding(.horizontal, 4) // 添加水平间距
        .background(Color(.systemBackground)) // 确保有背景色
    }
}
