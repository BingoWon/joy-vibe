//
//  NetworkPermissionView.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import SwiftUI

/// 网络权限状态显示视图
struct NetworkPermissionView: View {
    let permissionStatus: LocalNetworkPermissionStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            statusIcon
            
            // 状态文本
            VStack(alignment: .leading, spacing: 4) {
                Text("Local Network Permission")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                
                if permissionStatus == .denied {
                    Text("Go to Settings > Privacy & Security > Local Network > JoyVibe to enable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch permissionStatus {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        case .waiting:
            Image(systemName: "clock.circle.fill")
                .foregroundColor(.orange)
                .font(.title2)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
                .font(.title2)
        }
    }
    
    private var statusDescription: String {
        switch permissionStatus {
        case .granted:
            return "Access granted - can discover local services"
        case .denied:
            return "Access denied - cannot discover local services"
        case .waiting:
            return "Waiting for permission or network availability"
        case .unknown:
            return "Permission status unknown"
        }
    }
    
    private var statusColor: Color {
        switch permissionStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        case .waiting:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        switch permissionStatus {
        case .granted:
            return Color.green.opacity(0.1)
        case .denied:
            return Color.red.opacity(0.1)
        case .waiting:
            return Color.orange.opacity(0.1)
        case .unknown:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch permissionStatus {
        case .granted:
            return Color.green.opacity(0.3)
        case .denied:
            return Color.red.opacity(0.3)
        case .waiting:
            return Color.orange.opacity(0.3)
        case .unknown:
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        NetworkPermissionView(permissionStatus: .granted)
        NetworkPermissionView(permissionStatus: .denied)
        NetworkPermissionView(permissionStatus: .waiting)
        NetworkPermissionView(permissionStatus: .unknown)
    }
    .padding()
}
