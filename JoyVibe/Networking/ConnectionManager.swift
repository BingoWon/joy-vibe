//
//  ConnectionManager.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation
import Combine
import SwiftUI

/// Modern connection manager for Zed editor integration
@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var discoveredServices: [ZedService] = []
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var currentService: ZedService?
    @Published private(set) var isScanning = false
    @Published private(set) var lastError: String?
    @Published private(set) var currentEditorState: EditorState?
    private let serviceDiscovery = ZedDiscoveryService()
    private let webSocketClient = WebSocketClient()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    /// Setup reactive bindings using Combine
    private func setupBindings() {
        Publishers.CombineLatest3(
            serviceDiscovery.$discoveredServices,
            serviceDiscovery.$isScanning,
            serviceDiscovery.$error
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] services, scanning, error in
            self?.discoveredServices = services
            self?.isScanning = scanning
            self?.lastError = error
        }
        .store(in: &cancellables)

        webSocketClient.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionState in
                self?.connectionState = connectionState
            }
            .store(in: &cancellables)

        webSocketClient.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessage(message)
            }
            .store(in: &cancellables)
    }

    /// Start service discovery
    func startScanning() { serviceDiscovery.startScanning() }

    /// Stop service discovery
    func stopScanning() { serviceDiscovery.stopScanning() }

    /// Refresh available services
    func refreshServices() {
        serviceDiscovery.stopScanning()
        serviceDiscovery.startScanning()
    }

    /// Connect to a Zed service
    func connect(to service: ZedService) async {
        currentService = service
        lastError = nil
        await webSocketClient.connect(to: service)
    }

    /// Disconnect from current service
    func disconnect() {
        webSocketClient.disconnect()
        currentService = nil
        currentEditorState = nil
    }

    /// Clear last error
    func clearError() { lastError = nil }

    /// Handle incoming messages
    private func handleMessage(_ message: ZedVisionMessage) {
        switch message {
        case .editorStateSync(let state):
            currentEditorState = state
        default:
            break
        }
    }
}

// MARK: - Computed Properties
extension ConnectionManager {
    var isConnected: Bool { connectionState.isConnected }

    var connectionStatusText: String {
        if let service = currentService {
            return "\(connectionState.description) - \(service.displayName)"
        }
        return connectionState.description
    }

    var currentFileInfo: String {
        guard let state = currentEditorState else { return "No file open" }
        let fileName = state.filePath?.components(separatedBy: "/").last ?? "Unknown"
        return "\(fileName) - Line \(state.cursorLine), Column \(state.cursorColumn)"
    }



    func connectionStatusColor() -> Color {
        switch connectionState {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        }
    }

    func connectionStatusIcon() -> String {
        switch connectionState {
        case .connected: return "checkmark.circle.fill"
        case .connecting, .reconnecting: return "arrow.clockwise.circle.fill"
        case .disconnected: return "circle"
        case .failed: return "xmark.circle.fill"
        }
    }
}
