//
//  MainControlView.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

/// 主控制视图 - 管理应用的窗口和沉浸式空间
struct MainControlView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var windowManager = WindowManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用标题
            Text("JoyVibe")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Multi-Window Control Center")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // 沉浸式空间控制
            immersiveSpaceSection
            
            Divider()
            
            // 窗口管理
            windowManagementSection
            
            Spacer()
            
            // 状态信息
            statusSection
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            resetWindowStatesOnAppear()
            logger.info("主控制视图已显示", category: .ui)
        }
    }

    // MARK: - 应用启动时重置窗口状态

    private func resetWindowStatesOnAppear() {
        logger.debug("重置窗口状态", category: .ui)

        // 立即关闭所有其他窗口
        dismissWindow(id: "terminal")
        dismissWindow(id: "file-browser")

        // 重置窗口管理器状态
        windowManager.closeTerminal()
        windowManager.closeFileBrowser()

        // 延迟再次确保关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismissWindow(id: "terminal")
            dismissWindow(id: "file-browser")
        }

        // 标记首次启动完成
        if windowManager.isFirstLaunch {
            windowManager.markFirstLaunchComplete()
        }
    }
    
    // MARK: - 沉浸式空间控制
    
    private var immersiveSpaceSection: some View {
        VStack(spacing: 12) {
            Text("Immersive Space")
                .font(.headline)
            
            if windowManager.isImmersiveSpaceOpen {
                Button("Exit Immersive Space") {
                    Task {
                        await dismissImmersiveSpace()
                        windowManager.closeImmersiveSpace()
                    }
                }
                .buttonStyle(.borderedProminent)
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

            Text(windowManager.isImmersiveSpaceOpen ? "🌌 Immersive mode active" : "🪟 Window mode")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - 窗口管理
    
    private var windowManagementSection: some View {
        VStack(spacing: 12) {
            Text("Windows")
                .font(.headline)
            
            VStack(spacing: 8) {
                terminalControlButton
                fileBrowserControlButton
            }
        }
    }
    
    // MARK: - 终端控制按钮

    private var terminalControlButton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundStyle(.blue)
                    Text("Terminal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("Interactive terminal with commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if windowManager.isTerminalOpen {
                Button("Close") {
                    dismissWindow(id: "terminal")
                    windowManager.closeTerminal()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            } else {
                Button("Open") {
                    openWindow(id: "terminal")
                    windowManager.openTerminal()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 文件浏览器控制按钮

    private var fileBrowserControlButton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.blue)
                    Text("File Browser")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("Browse and preview files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if windowManager.isFileBrowserOpen {
                Button("Close") {
                    dismissWindow(id: "file-browser")
                    windowManager.closeFileBrowser()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            } else {
                Button("Open") {
                    openWindow(id: "file-browser")
                    windowManager.openFileBrowser()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 状态信息
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("Status")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Mode:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(windowManager.isImmersiveSpaceOpen ? "Immersive" : "Windowed")
                        .foregroundStyle(windowManager.isImmersiveSpaceOpen ? .blue : .secondary)
                }

                HStack {
                    Text("Open Windows:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(windowManager.openWindowsCount)")
                        .foregroundStyle(.secondary)
                }

                if windowManager.openWindowsCount > 0 {
                    HStack {
                        Text("Active:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(windowManager.activeWindowsList)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }


}

#Preview {
    MainControlView()
}
