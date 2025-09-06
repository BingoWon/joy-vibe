//
//  WebSocketClient.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation
import Combine

/// WebSocket 代理类，处理连接状态变化
private class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("🔌 WebSocket connection closed with code: \(closeCode)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            logger.info("🔌 Close reason: \(reasonString)")
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        logger.info("🔌 WebSocket connection opened")
        if let protocolName = protocolName {
            logger.info("🔌 Using protocol: \(protocolName)")
        }
    }
}



/// 现代化 WebSocket 客户端
@MainActor
final class WebSocketClient: ObservableObject {
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    private var connectionId: String?

    private var pingTimer: Timer?

    private let messageSubject = PassthroughSubject<ZedVisionMessage, Never>()
    var messagePublisher: AnyPublisher<ZedVisionMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.urlSession = URLSession(configuration: config, delegate: WebSocketDelegate(), delegateQueue: nil)
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        pingTimer?.invalidate()
    }
    
    /// 连接到 Zed 服务
    func connect(to service: ZedService) async {
        guard let url = service.webSocketURL else {
            connectionState = .failed(WebSocketError.invalidURL)
            return
        }

        disconnect()
        connectionState = .connecting

        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()

        startListening()

        // 发送简单的 hello 消息
        do {
            try await webSocketTask?.send(.string("hello"))
            // 连接状态将在收到响应时更新
        } catch {
            connectionState = .failed(error)
        }
    }

    /// 断开连接
    func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionId = nil
        connectionState = .disconnected
    }
    
    /// 发送消息
    func sendMessage(_ message: ZedVisionMessage) async {
        guard connectionState.isConnected else { return }

        do {
            let data = try JSONEncoder().encode(message)
            let string = String(data: data, encoding: .utf8) ?? ""
            try await webSocketTask?.send(.string(string))
        } catch {
            connectionState = .failed(error)
        }
    }
    
    /// 开始监听消息
    private func startListening() {
        guard let webSocketTask = webSocketTask else { return }

        Task {
            do {
                let message = try await webSocketTask.receive()
                await handleMessage(message)

                if connectionState.isConnected {
                    startListening()
                }
            } catch {
                logger.error("❌ WebSocket listening error: \(error)")
                connectionState = .failed(error)

                // 检查是否需要自动重连
                if case .connected = connectionState {
                    logger.info("🔄 Connection lost, attempting to reconnect...")
                    // 这里可以添加自动重连逻辑
                }
            }
        }
    }

    /// 处理消息
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        let text: String
        switch message {
        case .string(let str):
            text = str
        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return
        }

        // 现代化消息处理：优先处理 JSON，兼容文本
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["type"] as? String == "ConnectionAccepted" {
            // 处理连接接受消息
            connectionState = .connected
            startPingTimer()
            logger.info("✅ Connected to Zed successfully")
        } else if text.contains("hello") {
            // 处理简单的 hello 响应
            switch connectionState {
            case .connecting:
                connectionState = .connected
                startPingTimer()
                logger.info("✅ Connected to Zed with simple protocol")
            default:
                break
            }
        } else {
            // 处理其他消息
            logger.info("📥 Received: \(text)")
        }
    }
    
    /// 启动心跳
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendMessage(.ping)
            }
        }
    }

    /// 停止心跳
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}


