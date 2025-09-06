//
//  Errors.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation

/// WebSocket 错误类型
enum WebSocketError: LocalizedError, Sendable {
    case invalidURL
    case connectionRejected(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionRejected(let reason):
            return "Connection rejected: \(reason)"
        }
    }
}
