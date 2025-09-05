import SwiftUI
import Foundation

/// 增强的交互式终端界面，支持拖动、缩放和工具栏
/// 专为 visionOS 设计，包含 toolbar 和 ornament 功能
struct InteractiveTerminalView: View {
    @Binding var position: SIMD3<Float>
    @Binding var scale: Float
    
    @State private var outputText: String = "Welcome to JoyVibe Interactive Terminal\n$ "
    @State private var currentInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var showInfo = false
    @State private var showSystemStats = false
    @State private var showFileManager = false
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool
    
    private let terminalProcessor = TerminalProcessor()
    
    var body: some View {
        VStack(spacing: 0) {
            // 终端头部工具栏
            terminalHeader
            
            // 终端输出区域
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(outputText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("terminal-output")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: outputText) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("terminal-output", anchor: .bottom)
                    }
                }
            }
            
            Divider()
                .background(.quaternary)
            
            // 输入区域
            terminalInput
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                terminalToolbarItems
            }
        }
        .ornament(
            visibility: showInfo ? .visible : .hidden,
            attachmentAnchor: .scene(.topTrailing),
            contentAlignment: .center
        ) {
            terminalInfoOrnament
        }
        .ornament(
            visibility: showSystemStats ? .visible : .hidden,
            attachmentAnchor: .scene(.topLeading),
            contentAlignment: .center
        ) {
            systemStatsOrnament
        }
        .ornament(
            visibility: showFileManager ? .visible : .hidden,
            attachmentAnchor: .scene(.bottomLeading),
            contentAlignment: .center
        ) {
            fileManagerOrnament
        }
        .ornament(
            visibility: showSettings ? .visible : .hidden,
            attachmentAnchor: .scene(.bottomTrailing),
            contentAlignment: .center
        ) {
            settingsOrnament
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    // MARK: - 视图组件
    
    private var terminalHeader: some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            
            Text("Interactive Terminal")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .hoverEffect()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var terminalInput: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Enter command...", text: $currentInput)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit {
                    executeCommand()
                }
                .onKeyPress(.upArrow) {
                    navigateHistory(direction: .up)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateHistory(direction: .down)
                    return .handled
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var terminalToolbarItems: some View {
        HStack(spacing: 12) {
            // 基础操作组
            Group {
                Button(action: clearTerminal) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(BorderedButtonStyle())

                Button(action: showHelp) {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .buttonStyle(BorderedButtonStyle())
            }

            Divider()
                .frame(height: 20)

            // 面板切换组
            Group {
                if showSystemStats {
                    Button(action: { showSystemStats.toggle() }) {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                } else {
                    Button(action: { showSystemStats.toggle() }) {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .buttonStyle(BorderedButtonStyle())
                }

                if showFileManager {
                    Button(action: { showFileManager.toggle() }) {
                        Label("Files", systemImage: "folder")
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                } else {
                    Button(action: { showFileManager.toggle() }) {
                        Label("Files", systemImage: "folder")
                    }
                    .buttonStyle(BorderedButtonStyle())
                }

                if showSettings {
                    Button(action: { showSettings.toggle() }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                } else {
                    Button(action: { showSettings.toggle() }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }

            Divider()
                .frame(height: 20)

            // 位置和缩放控制组
            Group {
                Button(action: resetPosition) {
                    Label("Reset Position", systemImage: "location")
                }
                .buttonStyle(BorderedButtonStyle())

                Button(action: resetScale) {
                    Label("Reset Scale", systemImage: "magnifyingglass")
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var terminalInfoOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminal Info")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Position: (\(String(format: "%.2f", position.x)), \(String(format: "%.2f", position.y)), \(String(format: "%.2f", position.z)))")
                Text("Scale: \(String(format: "%.2f", scale))")
                Text("Commands: \(commandHistory.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Gestures:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("• Drag to move")
                Text("• Pinch to scale")
                Text("• Use toolbar for actions")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 200)
    }

    private var systemStatsOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Statistics")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))")
                Text("Cores: \(ProcessInfo.processInfo.processorCount)")
                Text("Uptime: \(formatUptime(ProcessInfo.processInfo.systemUptime))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Refresh Stats") {
                Task {
                    let _ = await terminalProcessor.execute(command: "top")
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 180)
    }

    private var fileManagerOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick File Operations")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                Button("List Files (ls)") {
                    executeQuickCommand("ls -la")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("Show Directory (pwd)") {
                    executeQuickCommand("pwd")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("Disk Usage (df)") {
                    executeQuickCommand("df")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("Go Home (~)") {
                    executeQuickCommand("cd ~")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 160)
    }

    private var settingsOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminal Settings")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                Button("Show Aliases") {
                    executeQuickCommand("alias")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("Environment") {
                    executeQuickCommand("env")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("Process Info") {
                    executeQuickCommand("ps")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("System Info") {
                    executeQuickCommand("uname")
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 140)
    }

    // MARK: - 功能函数
    
    private func executeCommand() {
        guard !currentInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let command = currentInput.trimmingCharacters(in: .whitespaces)
        
        // 添加到历史
        commandHistory.append(command)
        historyIndex = -1
        
        // 添加命令到输出
        outputText += command + "\n"
        
        // 执行命令
        Task {
            let result = await terminalProcessor.execute(command: command)
            await MainActor.run {
                outputText += result + "\n$ "
                currentInput = ""
            }
        }
        
        currentInput = ""
    }
    
    private enum HistoryDirection {
        case up, down
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        
        switch direction {
        case .up:
            if historyIndex == -1 {
                historyIndex = commandHistory.count - 1
            } else if historyIndex > 0 {
                historyIndex -= 1
            }
        case .down:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
            } else {
                historyIndex = -1
                currentInput = ""
                return
            }
        }
        
        if historyIndex >= 0 && historyIndex < commandHistory.count {
            currentInput = commandHistory[historyIndex]
        }
    }
    
    private func clearTerminal() {
        outputText = "Terminal cleared\n$ "
    }
    
    private func resetPosition() {
        position = [0, 1.0, -2.0]
    }
    
    private func resetScale() {
        scale = 1.0
    }
    
    private func showHelp() {
        executeQuickCommand("help")
    }

    private func executeQuickCommand(_ command: String) {
        Task {
            let result = await terminalProcessor.execute(command: command)
            await MainActor.run {
                outputText += command + "\n" + result + "\n$ "
            }
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    InteractiveTerminalView(
        position: .constant([0, 1.0, -2.0]),
        scale: .constant(1.0)
    )
    .frame(width: 600, height: 400)
    .padding()
}
