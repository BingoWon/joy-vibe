//
//  ZedService.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation

/// Modern Zed service information model
struct ZedService: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
    let version: String
    let platform: String
    let app: String

    var displayName: String { app }
    var webSocketURL: URL? { URL(string: "ws://\(host):\(port)") }
}
