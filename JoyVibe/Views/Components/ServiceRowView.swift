//
//  ServiceRowView.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import SwiftUI

/// Service row view for displaying Zed service information
struct ServiceRowView: View {
    let service: ZedService
    let isConnected: Bool
    let onConnect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.displayName)
                    .font(.headline)
                
                Text("\(service.platform) \(service.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(service.host):\(service.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isConnected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
