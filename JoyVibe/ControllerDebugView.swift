import SwiftUI
import GameController

// MARK: - Controller Debug Models

struct ControllerButtonState {
    let name: String
    let displayName: String
    let isPressed: Bool
    let value: Float
    let category: ButtonCategory
}

enum ButtonCategory: String, CaseIterable {
    case faceButtons = "Face Buttons"
    case shoulderButtons = "Shoulder Buttons"
    case triggers = "Triggers"
    case sticks = "Analog Sticks"
    case dpad = "D-Pad"
    case systemButtons = "System Buttons"
    case touchpad = "Touchpad"
}

struct ControllerState {
    let isConnected: Bool
    let name: String
    let vendorName: String?
    let productCategory: String
    let buttons: [ControllerButtonState]
    let leftStick: (x: Float, y: Float)
    let rightStick: (x: Float, y: Float)
    let leftTrigger: Float
    let rightTrigger: Float
    let dpadState: (up: Bool, down: Bool, left: Bool, right: Bool)
    let touchpadState: (isPressed: Bool, x: Float, y: Float)
}

// MARK: - Controller Debug Manager

@MainActor
class ControllerDebugManager: ObservableObject {
    @Published var controllerState = ControllerState(
        isConnected: false,
        name: "No Controller",
        vendorName: nil,
        productCategory: "Unknown",
        buttons: [],
        leftStick: (0, 0),
        rightStick: (0, 0),
        leftTrigger: 0,
        rightTrigger: 0,
        dpadState: (false, false, false, false),
        touchpadState: (false, 0, 0)
    )
    
    @Published var lastButtonPressed: String = "None"
    @Published var buttonPressCount: Int = 0
    
    private var currentController: GCController?
    
    init() {
        setupControllerObservers()
        updateControllerState()
    }
    
    private func setupControllerObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }
    }
    
    func updateControllerState() {
        let controllers = GCController.controllers()
        
        guard let controller = controllers.first else {
            controllerState = ControllerState(
                isConnected: false,
                name: "No Controller",
                vendorName: nil,
                productCategory: "Unknown",
                buttons: [],
                leftStick: (0, 0),
                rightStick: (0, 0),
                leftTrigger: 0,
                rightTrigger: 0,
                dpadState: (false, false, false, false),
                touchpadState: (false, 0, 0)
            )
            currentController = nil
            return
        }
        
        currentController = controller
        setupControllerHandlers(controller)
        
        // Get basic controller info
        let name = controller.vendorName ?? "Unknown Controller"
        let productCategory = controller.productCategory
        
        // Create button states array
        var buttons: [ControllerButtonState] = []
        
        if let extendedGamepad = controller.extendedGamepad {
            // Face buttons
            buttons.append(ControllerButtonState(
                name: "buttonA", displayName: "Cross (×)", 
                isPressed: extendedGamepad.buttonA.isPressed,
                value: extendedGamepad.buttonA.value,
                category: .faceButtons
            ))
            buttons.append(ControllerButtonState(
                name: "buttonB", displayName: "Circle (○)", 
                isPressed: extendedGamepad.buttonB.isPressed,
                value: extendedGamepad.buttonB.value,
                category: .faceButtons
            ))
            buttons.append(ControllerButtonState(
                name: "buttonX", displayName: "Square (□)", 
                isPressed: extendedGamepad.buttonX.isPressed,
                value: extendedGamepad.buttonX.value,
                category: .faceButtons
            ))
            buttons.append(ControllerButtonState(
                name: "buttonY", displayName: "Triangle (△)", 
                isPressed: extendedGamepad.buttonY.isPressed,
                value: extendedGamepad.buttonY.value,
                category: .faceButtons
            ))
            
            // Shoulder buttons
            buttons.append(ControllerButtonState(
                name: "leftShoulder", displayName: "L1", 
                isPressed: extendedGamepad.leftShoulder.isPressed,
                value: extendedGamepad.leftShoulder.value,
                category: .shoulderButtons
            ))
            buttons.append(ControllerButtonState(
                name: "rightShoulder", displayName: "R1", 
                isPressed: extendedGamepad.rightShoulder.isPressed,
                value: extendedGamepad.rightShoulder.value,
                category: .shoulderButtons
            ))
            
            // System buttons
            buttons.append(ControllerButtonState(
                name: "buttonMenu", displayName: "Options",
                isPressed: extendedGamepad.buttonMenu.isPressed,
                value: extendedGamepad.buttonMenu.value,
                category: .systemButtons
            ))

            if let buttonOptions = extendedGamepad.buttonOptions {
                buttons.append(ControllerButtonState(
                    name: "buttonOptions", displayName: "Share",
                    isPressed: buttonOptions.isPressed,
                    value: buttonOptions.value,
                    category: .systemButtons
                ))
            }
        }
        
        controllerState = ControllerState(
            isConnected: true,
            name: name,
            vendorName: controller.vendorName,
            productCategory: productCategory,
            buttons: buttons,
            leftStick: getCurrentStickState(controller, isLeft: true),
            rightStick: getCurrentStickState(controller, isLeft: false),
            leftTrigger: getCurrentTriggerState(controller, isLeft: true),
            rightTrigger: getCurrentTriggerState(controller, isLeft: false),
            dpadState: getCurrentDpadState(controller),
            touchpadState: getCurrentTouchpadState(controller)
        )
    }
    
    private func setupControllerHandlers(_ controller: GCController) {
        guard let extendedGamepad = controller.extendedGamepad else { return }
        
        // Setup button handlers
        let buttons = [
            ("Cross", extendedGamepad.buttonA),
            ("Circle", extendedGamepad.buttonB),
            ("Square", extendedGamepad.buttonX),
            ("Triangle", extendedGamepad.buttonY),
            ("L1", extendedGamepad.leftShoulder),
            ("R1", extendedGamepad.rightShoulder)
        ]
        
        for (name, button) in buttons {
            button.pressedChangedHandler = { [weak self] _, _, pressed in
                Task { @MainActor in
                    if pressed {
                        self?.lastButtonPressed = name
                        self?.buttonPressCount += 1
                    }
                    self?.updateControllerState()
                }
            }
        }

        // Setup trigger handlers
        extendedGamepad.leftTrigger.valueChangedHandler = { [weak self] _, _, _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }
        extendedGamepad.rightTrigger.valueChangedHandler = { [weak self] _, _, _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }

        // Setup stick handlers
        extendedGamepad.leftThumbstick.valueChangedHandler = { [weak self] _, _, _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }
        extendedGamepad.rightThumbstick.valueChangedHandler = { [weak self] _, _, _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }

        // Setup D-pad handler
        extendedGamepad.dpad.valueChangedHandler = { [weak self] _, _, _ in
            Task { @MainActor in
                self?.updateControllerState()
            }
        }
    }
    
    private func getCurrentStickState(_ controller: GCController, isLeft: Bool) -> (x: Float, y: Float) {
        guard let extendedGamepad = controller.extendedGamepad else { return (0, 0) }
        let stick = isLeft ? extendedGamepad.leftThumbstick : extendedGamepad.rightThumbstick
        return (stick.xAxis.value, stick.yAxis.value)
    }
    
    private func getCurrentTriggerState(_ controller: GCController, isLeft: Bool) -> Float {
        guard let extendedGamepad = controller.extendedGamepad else { return 0 }
        return isLeft ? extendedGamepad.leftTrigger.value : extendedGamepad.rightTrigger.value
    }
    
    private func getCurrentDpadState(_ controller: GCController) -> (up: Bool, down: Bool, left: Bool, right: Bool) {
        guard let extendedGamepad = controller.extendedGamepad else { return (false, false, false, false) }
        let dpad = extendedGamepad.dpad
        return (
            dpad.up.isPressed,
            dpad.down.isPressed,
            dpad.left.isPressed,
            dpad.right.isPressed
        )
    }
    
    private func getCurrentTouchpadState(_ controller: GCController) -> (isPressed: Bool, x: Float, y: Float) {
        // For now, return default values - will implement touchpad detection later
        return (false, 0, 0)
    }
}

// MARK: - Controller Debug View

struct ControllerDebugView: View {
    @StateObject private var debugManager = ControllerDebugManager()
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView

            if debugManager.controllerState.isConnected {
                // Controller info and Statistics in same row
                HStack(alignment: .top, spacing: 16) {
                    controllerInfoView
                    statisticsView
                }

                // Button states and Analog inputs in same row
                HStack(alignment: .top, spacing: 16) {
                    buttonCategoriesView
                    analogInputsView
                }

                // Function guide
                functionGuideView
            } else {
                noControllerView
            }
        }
        .padding(24)
        .frame(minWidth: 600, maxWidth: 800, minHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundColor(debugManager.controllerState.isConnected ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Controller Debug")
                    .font(.headline)
                    .fontWeight(.bold)

                Text(debugManager.controllerState.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Refresh") {
                debugManager.updateControllerState()
            }
            .buttonStyle(.bordered)
            .font(.caption)

            Button(action: {
                onClose?()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Debug Panel")
        }
    }

    private var controllerInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Controller Information")
                .font(.subheadline)
                .fontWeight(.semibold)

            infoRow("Name:", debugManager.controllerState.name)
            infoRow("Vendor:", debugManager.controllerState.vendorName ?? "Unknown")
            infoRow("Category:", debugManager.controllerState.productCategory)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private var buttonCategoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Button States")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(debugManager.controllerState.buttons, id: \.name) { button in
                    buttonStateView(button)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private func buttonStateView(_ button: ControllerButtonState) -> some View {
        HStack {
            Circle()
                .fill(button.isPressed ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(button.displayName)
                .font(.caption)
                .fontWeight(button.isPressed ? .semibold : .regular)
                .foregroundColor(button.isPressed ? .primary : .secondary)

            Spacer()

            if button.value > 0 {
                Text(String(format: "%.2f", button.value))
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(button.isPressed ? .green.opacity(0.1) : .clear)
        .cornerRadius(6)
    }

    private var analogInputsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analog Inputs")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 20) {
                // Left stick
                analogStickView("Left Stick", debugManager.controllerState.leftStick)

                // Left trigger
                triggerView("L2", debugManager.controllerState.leftTrigger)

                // Right trigger
                triggerView("R2", debugManager.controllerState.rightTrigger)

                // Right stick
                analogStickView("Right Stick", debugManager.controllerState.rightStick)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private func analogStickView(_ title: String, _ stick: (x: Float, y: Float)) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)

                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: CGFloat(stick.x) * 26,
                        y: CGFloat(-stick.y) * 26
                    )
            }

            Text("X: \(String(format: "%.2f", stick.x))")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Y: \(String(format: "%.2f", stick.y))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func triggerView(_ title: String, _ value: Float) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 30, height: 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.orange)
                    .frame(width: 26, height: CGFloat(value) * 56)
            }

            Text(String(format: "%.2f", value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var functionGuideView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal Functions Guide")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                functionGuideItem("Cross (×)", "Execute command", .green)
                functionGuideItem("Circle (○)", "Clear input", .orange)
                functionGuideItem("Square (□)", "Clear screen", .blue)
                functionGuideItem("Triangle (△)", "Quick commands", .purple)
                functionGuideItem("L1", "Previous word", .cyan)
                functionGuideItem("R1", "Next word", .cyan)
                functionGuideItem("L2", "Scroll up", .yellow)
                functionGuideItem("R2", "Scroll down", .yellow)
                functionGuideItem("D-Pad ↑↓", "Command history", .pink)
                functionGuideItem("D-Pad ←→", "Move cursor", .pink)
                functionGuideItem("Left Stick", "Cursor control", .mint)
                functionGuideItem("Right Stick", "Scroll terminal", .mint)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func functionGuideItem(_ button: String, _ function: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(button)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)

            Text(function)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.subheadline)
                .fontWeight(.semibold)

            infoRow("Last Button:", debugManager.lastButtonPressed)
            infoRow("Press Count:", "\(debugManager.buttonPressCount)")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private var noControllerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Controller Connected")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Connect a PS5 DualSense controller to see detailed debug information.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
