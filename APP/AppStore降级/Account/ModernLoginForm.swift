//
//  ModernLoginForm.swift
//
//  Created by pxx917144686 on 2025/08/20.
//
import SwiftUI
struct ModernLoginForm: View {
    @Binding var appleId: String
    @Binding var password: String
    @Binding var code: String?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    var showCodeField: Bool = false
    var onLogin: () -> Void
    var showCodeHelp: Bool = true
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(showCodeField ? "输入验证码" : "登录 App Store")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("信息是直接发送给Apple公司")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 10)
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(showCodeField ? "Apple ID" : "Apple ID")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    TextField("请输入您的 Apple ID", text: $appleId)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                if !showCodeField {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        SecureField("请输入密码", text: $password)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                if showCodeField {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("双重认证代码")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("请输入2FA验证码", text: Binding(get: { code ?? "" }, set: { code = $0 }))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .keyboardType(.numberPad)
                    }
                }
            }
            Button(action: {
                onLogin()
            }) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(showCodeField ? "验证" : "登录认证")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            .disabled(isLoading || appleId.isEmpty || (!showCodeField && password.isEmpty) || (showCodeField && (code?.isEmpty ?? true)))
            // 显示错误消息或帮助信息
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
            } else if showCodeHelp && !showCodeField {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("需要提供双重认证代码2FA才能成功登录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.vertical, 20)
    }
}