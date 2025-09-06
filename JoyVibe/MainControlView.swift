//
//  MainControlView.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

/// Modern main control view focused on Zed connection management
struct MainControlView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var windowManager = WindowManager.shared
    @StateObject private var connectionManager = ConnectionManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App header
                headerSection
                // Unified connection management
                connectionSection
                // Quick actions
                quickActionsSection
                // Immersive space control
                immersiveSpaceSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            resetWindowStatesOnAppear()
            connectionManager.startScanning()
            logger.info("Main control view appeared", category: .ui)
        }
        .alert("Connection Error", isPresented: .constant(connectionManager.lastError != nil)) {
            Button("OK") {
                connectionManager.clearError()
            }
        } message: {
            Text(connectionManager.lastError ?? "")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("JoyVibe")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Connect to Zed Editor")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Connection header
            HStack {
                Text("Zed Connection")
                    .font(.headline)
                Spacer()
                // Unified refresh functionality
                HStack(spacing: 12) {
                    if connectionManager.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Button("Refresh") {
                        connectionManager.refreshServices()
                    }
                    .buttonStyle(.bordered)
                    .disabled(connectionManager.isScanning)
                }
            }
            // Connection status indicator
            HStack(spacing: 16) {
                Image(systemName: connectionManager.connectionStatusIcon())
                    .font(.title)
                    .foregroundColor(connectionManager.connectionStatusColor())

                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionManager.connectionStatusText)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !connectionManager.discoveredServices.isEmpty {
                        Text("Found \(connectionManager.discoveredServices.count) Zed instance(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            // Dynamic connection content
            if connectionManager.isConnected, let service = connectionManager.currentService {
                connectedServiceDetails(service: service)
            } else {
                availableServicesSection
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Connected Service Details

    private func connectedServiceDetails(service: ZedService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection info
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to \(service.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Disconnect") {
                    connectionManager.disconnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("WebSocket: \(service.webSocketURL?.absoluteString ?? "N/A")")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            // Editor state information
            if let editorState = connectionManager.currentEditorState {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Editor State")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current File")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(editorState.filePath ?? "No file open")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Text("Line \(editorState.cursorLine)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Available Services

    private var availableServicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if connectionManager.discoveredServices.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text(connectionManager.isScanning ? "Scanning for Zed instances..." : "No Zed instances found")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if !connectionManager.isScanning {
                        Text("Make sure Zed is running with ZedVision enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Services list
                ForEach(connectionManager.discoveredServices) { service in
                    ServiceRowView(
                        service: service,
                        isConnected: connectionManager.currentService?.id == service.id,
                        onConnect: {
                            Task {
                                await connectionManager.connect(to: service)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Window State Management

    private func resetWindowStatesOnAppear() {
        logger.debug("Resetting window states", category: .ui)
        // Close all auxiliary windows
        dismissWindow(id: "terminal")
        dismissWindow(id: "file-browser")
        // Reset window manager state
        windowManager.closeTerminal()
        windowManager.closeFileBrowser()
        // Mark first launch complete
        if windowManager.isFirstLaunch {
            windowManager.markFirstLaunchComplete()
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 16) {
                quickActionButton(
                    title: "Terminal",
                    icon: "terminal",
                    color: .blue,
                    isOpen: windowManager.isTerminalOpen,
                    action: {
                        if windowManager.isTerminalOpen {
                            dismissWindow(id: "terminal")
                            windowManager.closeTerminal()
                        } else {
                            openWindow(id: "terminal")
                            windowManager.openTerminal()
                        }
                    }
                )

                quickActionButton(
                    title: "File Browser",
                    icon: "folder",
                    color: .orange,
                    isOpen: windowManager.isFileBrowserOpen,
                    action: {
                        if windowManager.isFileBrowserOpen {
                            dismissWindow(id: "file-browser")
                            windowManager.closeFileBrowser()
                        } else {
                            openWindow(id: "file-browser")
                            windowManager.openFileBrowser()
                        }
                    }
                )

                Spacer()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func quickActionButton(title: String, icon: String, color: Color, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)

                Text(isOpen ? "Open" : "Closed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, height: 80)
            .background(isOpen ? color.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOpen ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Immersive Space Control

    private var immersiveSpaceSection: some View {
        VStack(spacing: 16) {
            Text("Immersive Experience")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: windowManager.isImmersiveSpaceOpen ? "xr.headset" : "rectangle.3.group")
                        .font(.title2)
                        .foregroundColor(windowManager.isImmersiveSpaceOpen ? .blue : .secondary)

                    Text(windowManager.isImmersiveSpaceOpen ? "Immersive" : "Windowed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if windowManager.isImmersiveSpaceOpen {
                    Button("Exit Immersive Space") {
                        Task {
                            await dismissImmersiveSpace()
                            windowManager.closeImmersiveSpace()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Enter Immersive Space") {
                        Task {
                            let result = await openImmersiveSpace(id: "immersive-space")
                            if case .opened = result {
                                windowManager.openImmersiveSpace()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MainControlView()
}
