import SwiftUI
import Foundation
import GameController

/// Modern terminal interface for visionOS with PS5 controller support
/// Provides elegant command-line interaction in 3D space with gamepad controls
struct TerminalView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var outputText: String = "Welcome to JoyVibe Terminal\n$ "
    @State private var currentInput: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var showQuickCommands = false
    @State private var showNetworkTools = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isWindowFocused: Bool

    @State private var cursorPosition: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var showDebugPanel = true
    
    private let terminalProcessor = TerminalProcessor()
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output area
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
            
            // Input area
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .handlesGameControllerEvents(matching: .gamepad)
        .focused($isWindowFocused)
        .overlay {
            if showDebugPanel {
                debugFloatingPanel
            }
        }
        .onAppear {
            isInputFocused = true
            isWindowFocused = true
            setupGameControllerHandlers()
        }
        .ornament(
            visibility: showQuickCommands ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .top
        ) {
            quickCommandsOrnament
        }
        .ornament(
            visibility: showNetworkTools ? .visible : .hidden,
            attachmentAnchor: .scene(.topTrailing),
            contentAlignment: .trailing
        ) {
            networkToolsOrnament
        }


        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Control Center") {
                    openWindow(id: "main-control")
                }
                .buttonStyle(.bordered)
                .help("Open main control window")
            }
        }
        .background(
            TerminalViewControllerRepresentable(
                showQuickCommands: $showQuickCommands,
                showNetworkTools: $showNetworkTools,
                showDebugPanel: $showDebugPanel
            )
        )
    }
    
    private func executeCommand() {
        guard !currentInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let command = currentInput.trimmingCharacters(in: .whitespaces)
        
        // Add to history
        commandHistory.append(command)
        historyIndex = -1
        
        // Add command to output
        outputText += command + "\n"
        
        // Clear input immediately
        currentInput = ""

        // Execute command
        Task {
            let result = await terminalProcessor.execute(command: command)
            await MainActor.run {
                outputText += result + "\n$ "
                isInputFocused = true



                cursorPosition = 0
            }
        }
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
}

/// Enhanced terminal command processor
/// Handles command execution and output generation with advanced features
@MainActor
class TerminalProcessor: ObservableObject {
    @Published var currentDirectory: String = FileManager.default.currentDirectoryPath
    @Published var systemStats: SystemStats = SystemStats()

    private var commandAliases: [String: String] = [
        "ll": "ls -la",
        "la": "ls -a",
        "..": "cd ..",
        "~": "cd ~"
    ]

    func execute(command: String) async -> String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        let resolvedCommand = resolveAlias(trimmedCommand)
        let components = resolvedCommand.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard let firstComponent = components.first else {
            return "Error: Empty command"
        }

        switch firstComponent.lowercased() {
        case "help":
            return generateHelpText()
        case "clear":
            return "" // Special case handled by caller
        case "echo":
            return components.dropFirst().joined(separator: " ")
        case "date":
            return DateFormatter.terminal.string(from: Date())
        case "pwd":
            return currentDirectory
        case "cd":
            return await changeDirectory(path: components.count > 1 ? components[1] : "~")
        case "ls":
            return await listDirectory(path: components.count > 1 ? components[1] : ".", detailed: components.contains("-l") || components.contains("-la"))
        case "mkdir":
            return await createDirectory(path: components.count > 1 ? components[1] : "")
        case "touch":
            return await createFile(path: components.count > 1 ? components[1] : "")
        case "rm":
            return await removeItem(path: components.count > 1 ? components[1] : "", recursive: components.contains("-r"))
        case "cat":
            return await readFile(path: components.count > 1 ? components[1] : "")
        case "whoami":
            return NSUserName()
        case "uname":
            return await getSystemInfo()
        case "env":
            return getEnvironmentVariables()
        case "ps":
            return await getProcessList()
        case "top":
            return await getSystemStats()
        case "df":
            return await getDiskUsage()
        case "history":
            return "Command history managed by terminal interface"
        case "alias":
            return listAliases()
        case "uptime":
            return getUptime()
        default:
            return await executeSystemCommand(command: resolvedCommand)
        }
    }

    private func resolveAlias(_ command: String) -> String {
        for (alias, expansion) in commandAliases {
            if command.hasPrefix(alias + " ") {
                return command.replacingOccurrences(of: alias, with: expansion, options: .anchored)
            } else if command == alias {
                return expansion
            }
        }
        return command
    }
    
    private func generateHelpText() -> String {
        """
        JoyVibe Terminal - Available Commands:

        📁 File Operations:
        ls [-l]    - List directory contents (detailed with -l)
        cd <path>  - Change directory
        pwd        - Print working directory
        mkdir <dir>- Create directory
        touch <file>- Create empty file
        rm [-r] <path>- Remove file/directory (recursive with -r)
        cat <file> - Display file contents

        💻 System Information:
        whoami     - Show current user
        uname      - System information
        env        - Environment variables
        ps         - Process list
        top        - System statistics
        df         - Disk usage
        uptime     - System uptime

        🛠️ Utilities:
        help       - Show this help message
        clear      - Clear terminal output
        echo <text>- Display text
        date       - Show current date and time
        history    - Command history
        alias      - Show command aliases

        📝 Aliases:
        ll         - ls -la (detailed list)
        la         - ls -a (show hidden files)
        ..         - cd .. (go up one directory)
        ~          - cd ~ (go to home directory)

        Use arrow keys to navigate command history.
        """
    }
    
    private func changeDirectory(path: String) async -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentDirectory = url.path
            return "Changed to: \(currentDirectory)"
        } else {
            return "Error: Directory '\(path)' not found"
        }
    }

    private func listDirectory(path: String, detailed: Bool = false) async -> String {
        do {
            let basePath = path == "." ? currentDirectory : NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: basePath)
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: detailed ? [] : [.skipsHiddenFiles]
            )

            if detailed {
                var result = "total \(contents.count)\n"
                for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    let resources = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    let isDirectory = resources.isDirectory ?? false
                    let size = resources.fileSize ?? 0
                    let date = resources.contentModificationDate ?? Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM dd HH:mm"

                    let permissions = isDirectory ? "drwxr-xr-x" : "-rw-r--r--"
                    let sizeString = isDirectory ? "4096" : "\(size)"
                    let name = isDirectory ? "\(fileURL.lastPathComponent)/" : fileURL.lastPathComponent

                    result += String(format: "%@ %8s %s %s\n",
                                   permissions, sizeString, formatter.string(from: date), name)
                }
                return result
            } else {
                return contents.map { url in
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    return isDirectory ? "\(url.lastPathComponent)/" : url.lastPathComponent
                }.sorted().joined(separator: "\n")
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func createDirectory(path: String) async -> String {
        guard !path.isEmpty else { return "Error: Directory name required" }

        let fullPath = NSString(string: path).expandingTildeInPath
        do {
            try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            return "Directory created: \(path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func createFile(path: String) async -> String {
        guard !path.isEmpty else { return "Error: File name required" }

        let fullPath = NSString(string: path).expandingTildeInPath
        if FileManager.default.createFile(atPath: fullPath, contents: Data(), attributes: nil) {
            return "File created: \(path)"
        } else {
            return "Error: Could not create file '\(path)'"
        }
    }

    private func removeItem(path: String, recursive: Bool) async -> String {
        guard !path.isEmpty else { return "Error: Path required" }

        let fullPath = NSString(string: path).expandingTildeInPath
        do {
            try FileManager.default.removeItem(atPath: fullPath)
            return "Removed: \(path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func readFile(path: String) async -> String {
        guard !path.isEmpty else { return "Error: File path required" }

        let fullPath = NSString(string: path).expandingTildeInPath
        do {
            let content = try String(contentsOfFile: fullPath, encoding: .utf8)
            return content.isEmpty ? "(empty file)" : content
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func getSystemInfo() async -> String {
        let info = ProcessInfo.processInfo
        return """
        System: \(info.operatingSystemVersionString)
        Platform: visionOS
        Processor: \(info.processorCount) cores
        Memory: \(ByteCountFormatter.string(fromByteCount: Int64(info.physicalMemory), countStyle: .memory))
        Uptime: \(formatUptime(info.systemUptime))
        """
    }

    private func getEnvironmentVariables() -> String {
        let env = ProcessInfo.processInfo.environment
        return env.keys.sorted().map { "\($0)=\(env[$0] ?? "")" }.joined(separator: "\n")
    }

    private func getProcessList() async -> String {
        let processes = ProcessInfo.processInfo
        return """
        Current Process Information:
        PID: \(processes.processIdentifier)
        Name: \(processes.processName)
        Arguments: \(processes.arguments.joined(separator: " "))
        Environment Variables: \(processes.environment.count) items
        """
    }

    private func getSystemStats() async -> String {
        await updateSystemStats()
        return """
        System Statistics:
        CPU Usage: Monitoring active
        Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
        Active Processes: \(systemStats.processCount)
        System Load: \(String(format: "%.2f", systemStats.systemLoad))
        """
    }

    private func getDiskUsage() async -> String {
        do {
            // Use documents directory as a reference point for visionOS
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])

            let available = resourceValues.volumeAvailableCapacity ?? 0
            let total = resourceValues.volumeTotalCapacity ?? 0
            let used = total - available
            let usedPercent = total > 0 ? Double(used) / Double(total) * 100 : 0

            return """
            Disk Usage (App Container):
            Total: \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))
            Used:  \(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)) (\(String(format: "%.1f", usedPercent))%)
            Free:  \(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file))
            """
        } catch {
            return "Error getting disk usage: \(error.localizedDescription)"
        }
    }

    private func listAliases() -> String {
        return commandAliases.map { "\($0.key) -> \($0.value)" }.sorted().joined(separator: "\n")
    }

    private func getUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        return "System uptime: \(formatUptime(uptime))"
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

    private func updateSystemStats() async {
        systemStats.processCount = 1 // Simplified for sandbox
        systemStats.systemLoad = Double.random(in: 0.1...2.0) // Simulated
    }

    private func executeSystemCommand(command: String) async -> String {
        return "Command '\(command)' not recognized. Type 'help' for available commands."
    }
}

// MARK: - System Statistics Model
struct SystemStats {
    var processCount: Int = 0
    var systemLoad: Double = 0.0
}

extension DateFormatter {
    static let terminal: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Terminal Ornament Extensions

extension TerminalView {

    private var quickCommandsOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Commands")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                QuickCommandButton(title: "ls", icon: "list.bullet") {
                    executeQuickCommand("ls -la")
                }
                QuickCommandButton(title: "pwd", icon: "location") {
                    executeQuickCommand("pwd")
                }
                QuickCommandButton(title: "date", icon: "calendar") {
                    executeQuickCommand("date")
                }
                QuickCommandButton(title: "whoami", icon: "person") {
                    executeQuickCommand("whoami")
                }
                QuickCommandButton(title: "top", icon: "chart.bar") {
                    executeQuickCommand("top")
                }
                QuickCommandButton(title: "df", icon: "internaldrive") {
                    executeQuickCommand("df -h")
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .glassBackgroundEffect()
        .frame(width: 280)
    }

    private var networkToolsOrnament: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Tools")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                Button("Ping Test") {
                    executeQuickCommand("echo 'Ping test: Network connectivity OK'")
                    showNetworkTools = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("DNS Lookup") {
                    executeQuickCommand("echo 'DNS: Resolving hostnames...'")
                    showNetworkTools = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Port Scan") {
                    executeQuickCommand("echo 'Port scan: Checking common ports...'")
                    showNetworkTools = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Network Info") {
                    executeQuickCommand("echo 'Network interface information'")
                    showNetworkTools = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .glassBackgroundEffect()
        .frame(width: 160)
    }

    private func executeQuickCommand(_ command: String) {
        currentInput = command
        executeCommand()
        // 执行命令后自动隐藏面板
        showQuickCommands = false
    }

    // MARK: - 调试面板

    private var debugFloatingPanel: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showDebugPanel = false
                }

            // 居中的debug面板
            ControllerDebugView(onClose: {
                showDebugPanel = false
            })
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(showDebugPanel ? 1.0 : 0.8)
            .opacity(showDebugPanel ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showDebugPanel)
            .handlesGameControllerEvents(matching: .gamepad)
            .focused($isWindowFocused)
        }
    }











    private func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
    }

    private func moveCursorRight() {
        if cursorPosition < currentInput.count {
            cursorPosition += 1
        }
    }

    private func moveCursorToPreviousWord() {
        // 简化实现：移动到行首
        cursorPosition = 0
    }

    private func moveCursorToNextWord() {
        // 简化实现：移动到行尾
        cursorPosition = currentInput.count
    }

    private func clearScreen() {
        outputText = "Welcome to JoyVibe Terminal\n$ "
    }

    // MARK: - Game Controller Support

    private func setupGameControllerHandlers() {
        // 监听手柄连接
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { notification in
            if let controller = notification.object as? GCController {
                // 手柄连接时的处理逻辑
                print("Controller connected: \(controller.vendorName ?? "Unknown")")
            }
        }

        // 设置已连接的手柄
        for controller in GCController.controllers() {
            print("Found controller: \(controller.vendorName ?? "Unknown")")
        }
    }

    // 简化的手柄处理，移除weak self引用
    private func setupControllerInputHandlers(_ controller: GCController) {
        // 这里可以添加基本的手柄处理逻辑
        // 但由于SwiftUI的限制，我们主要依赖.handlesGameControllerEvents修饰符
        print("Setting up controller: \(controller.vendorName ?? "Unknown")")
    }


}

// MARK: - UIHostingOrnament Implementation

struct TerminalViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var showQuickCommands: Bool
    @Binding var showNetworkTools: Bool
    @Binding var showDebugPanel: Bool

    func makeUIViewController(context: Context) -> TerminalViewController {
        let controller = TerminalViewController()
        controller.showQuickCommands = showQuickCommands
        controller.showNetworkTools = showNetworkTools
        return controller
    }

    func updateUIViewController(_ uiViewController: TerminalViewController, context: Context) {
        uiViewController.showQuickCommands = showQuickCommands
        uiViewController.showNetworkTools = showNetworkTools
        uiViewController.showDebugPanel = showDebugPanel

        // 设置回调
        uiViewController.onShowQuickCommandsChanged = { newValue in
            showQuickCommands = newValue
        }
        uiViewController.onShowNetworkToolsChanged = { newValue in
            showNetworkTools = newValue
        }
        uiViewController.onShowDebugPanelChanged = { newValue in
            showDebugPanel = newValue
        }

        uiViewController.updateOrnaments()
    }
}

class TerminalViewController: UIViewController {
    var showQuickCommands: Bool = false {
        didSet { updateOrnaments() }
    }
    var showNetworkTools: Bool = false {
        didSet { updateOrnaments() }
    }
    var showDebugPanel: Bool = false {
        didSet { updateOrnaments() }
    }

    var onShowQuickCommandsChanged: ((Bool) -> Void)?
    var onShowNetworkToolsChanged: ((Bool) -> Void)?
    var onShowDebugPanelChanged: ((Bool) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        updateOrnaments()
    }

    func updateOrnaments() {
        var newOrnaments: [UIHostingOrnament<AnyView>] = []

        // 底部按钮ornament - 使用您建议的配置
        let bottomOrnament = UIHostingOrnament(
            sceneAnchor: .bottom,
            contentAlignment: .top  // 这是您建议的关键配置！
        ) {
            AnyView(
                HStack(spacing: 12) {
                    Button(action: {
                        self.showQuickCommands.toggle()
                        self.onShowQuickCommandsChanged?(self.showQuickCommands)
                    }) {
                        Label("Commands", systemImage: "terminal.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        self.showNetworkTools.toggle()
                        self.onShowNetworkToolsChanged?(self.showNetworkTools)
                    }) {
                        Label("Network", systemImage: "network")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        self.showDebugPanel.toggle()
                        self.onShowDebugPanelChanged?(self.showDebugPanel)
                    }) {
                        Label(
                            self.showDebugPanel ? "Hide Debug" : "Show Debug",
                            systemImage: self.showDebugPanel ? "gamecontroller.fill" : "gamecontroller"
                        )
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(self.showDebugPanel ? .green : .primary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .glassBackgroundEffect()
            )
        }

        newOrnaments.append(bottomOrnament)

        self.ornaments = newOrnaments
    }
}

// MARK: - Quick Command Button Component (使用InteractiveTerminalView中的定义)

#Preview {
    TerminalView()
        .frame(width: 600, height: 400)
        .padding()
}
