//
//  Messages.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation

/// Helper type for handling dynamic JSON data
struct AnyCodable: Codable, Sendable {
    let value: Any

    init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let uint64 = try? container.decode(UInt64.self) {
            value = uint64
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let anyArray = array.map { AnyCodable($0) }
            try container.encode(anyArray)
        case let dictionary as [String: Any]:
            let anyDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(anyDictionary)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }

    var stringValue: String? { value as? String }
    var uint64Value: UInt64? { value as? UInt64 }
    var dictionaryValue: [String: AnyCodable] {
        if let dict = value as? [String: Any] {
            return dict.mapValues { AnyCodable($0) }
        }
        return [:]
    }

    func decode<T: Codable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(type, from: data)
    }
}

/// WebSocket 连接状态
enum WebSocketConnectionState: Sendable {
    case disconnected, connecting, connected, reconnecting
    case failed(Error)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
}

/// Unified Zed Vision message types (matching Rust backend format)
enum ZedVisionMessage: Codable, Sendable {
    case connectionRequest(deviceName: String)
    case connectionAccepted(connectionId: String, serverInfo: ServerInfo)
    case connectionRejected(reason: String)
    case editorStateSync(EditorState)
    case ping, pong
    case echo(original: [String: AnyCodable], timestamp: UInt64)

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum MessageType: String, Codable {
        case connectionRequest = "ConnectionRequest"
        case connectionAccepted = "ConnectionAccepted"
        case connectionRejected = "ConnectionRejected"
        case editorStateSync = "EditorStateSync"
        case ping = "Ping"
        case pong = "Pong"
        case echo = "Echo"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .connectionRequest:
            if container.contains(.payload) {
                let payload = try container.decode([String: String].self, forKey: .payload)
                let deviceName = payload["device_name"] ?? ""
                self = .connectionRequest(deviceName: deviceName)
            } else {
                self = .connectionRequest(deviceName: "")
            }
        case .connectionAccepted:
            if container.contains(.payload) {
                let payload = try container.decode([String: AnyCodable].self, forKey: .payload)
                let connectionId = payload["connection_id"]?.stringValue ?? ""
                let serverInfo = try payload["server_info"]?.decode(ServerInfo.self) ?? ServerInfo(name: "Zed", version: "1.0", platform: "macOS")
                self = .connectionAccepted(connectionId: connectionId, serverInfo: serverInfo)
            } else {
                self = .connectionAccepted(connectionId: "", serverInfo: ServerInfo(name: "Zed", version: "1.0", platform: "macOS"))
            }
        case .connectionRejected:
            if container.contains(.payload) {
                let payload = try container.decode([String: String].self, forKey: .payload)
                let reason = payload["reason"] ?? ""
                self = .connectionRejected(reason: reason)
            } else {
                self = .connectionRejected(reason: "")
            }
        case .editorStateSync:
            let editorState = try container.decode(EditorState.self, forKey: .payload)
            self = .editorStateSync(editorState)

        case .ping:
            self = .ping
        case .pong:
            self = .pong
        case .echo:
            if container.contains(.payload) {
                let payload = try container.decode([String: AnyCodable].self, forKey: .payload)
                let original = payload["original"]?.value as? [String: AnyCodable] ?? [:]
                let timestamp = payload["timestamp"]?.uint64Value ?? 0
                self = .echo(original: original, timestamp: timestamp)
            } else {
                self = .echo(original: [:], timestamp: 0)
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .connectionRequest(let deviceName):
            try container.encode(MessageType.connectionRequest, forKey: .type)
            let payload = ["device_name": deviceName]
            try container.encode(payload, forKey: .payload)
        case .connectionAccepted(let connectionId, let serverInfo):
            try container.encode(MessageType.connectionAccepted, forKey: .type)
            let payload: [String: Any] = [
                "connection_id": connectionId,
                "server_info": [
                    "name": serverInfo.name,
                    "version": serverInfo.version,
                    "platform": serverInfo.platform
                ]
            ]
            try container.encode(AnyCodable(payload), forKey: .payload)
        case .connectionRejected(let reason):
            try container.encode(MessageType.connectionRejected, forKey: .type)
            let payload = ["reason": reason]
            try container.encode(payload, forKey: .payload)
        case .editorStateSync(let editorState):
            try container.encode(MessageType.editorStateSync, forKey: .type)
            try container.encode(editorState, forKey: .payload)

        case .ping:
            try container.encode(MessageType.ping, forKey: .type)
        case .pong:
            try container.encode(MessageType.pong, forKey: .type)
        case .echo(let original, let timestamp):
            try container.encode(MessageType.echo, forKey: .type)
            let payload: [String: AnyCodable] = [
                "original": AnyCodable(original),
                "timestamp": AnyCodable(timestamp)
            ]
            try container.encode(payload, forKey: .payload)
        }
    }
}

/// Editor state information
struct EditorState: Codable, Sendable {
    let filePath: String?
    let cursorLine: UInt32
    let cursorColumn: UInt32
    let contentPreview: String
    
    private enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case cursorLine = "cursor_line"
        case cursorColumn = "cursor_column"
        case contentPreview = "content_preview"
    }
}

/// Server information
struct ServerInfo: Codable, Sendable {
    let name: String
    let version: String
    let platform: String
}


