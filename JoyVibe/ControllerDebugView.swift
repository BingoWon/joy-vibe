import SwiftUI
import GameController

// MARK: - Models

struct ControllerButton {
    let name: String
    let displayName: String
    let isPressed: Bool
}

struct ControllerState {
    let isConnected: Bool
    let name: String
    let vendorName: String?
    let productCategory: String
    let buttons: [ControllerButton]
    let leftStick: (x: Float, y: Float, pressed: Bool)
    let rightStick: (x: Float, y: Float, pressed: Bool)
    let leftTrigger: Float
    let rightTrigger: Float

    static let empty = ControllerState(
        isConnected: false,
        name: "No Controller",
        vendorName: nil,
        productCategory: "Unknown",
        buttons: [],
        leftStick: (0, 0, false),
        rightStick: (0, 0, false),
        leftTrigger: 0,
        rightTrigger: 0
    )
}

// MARK: - Manager

@MainActor
class ControllerDebugManager: ObservableObject {
    @Published var controllerState = ControllerState.empty
    private var currentController: GCController?

    init() {
        setupObservers()
        updateState()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
    }

    func updateState() {
        guard let controller = GCController.controllers().first,
              let gamepad = controller.extendedGamepad else {
            controllerState = .empty
            currentController = nil
            return
        }

        if currentController !== controller {
            currentController = controller
            setupHandlers(gamepad)
        }

        controllerState = ControllerState(
            isConnected: true,
            name: controller.vendorName ?? "Unknown Controller",
            vendorName: controller.vendorName,
            productCategory: controller.productCategory,
            buttons: createButtons(gamepad),
            leftStick: (
                gamepad.leftThumbstick.xAxis.value,
                gamepad.leftThumbstick.yAxis.value,
                gamepad.leftThumbstickButton?.isPressed ?? false
            ),
            rightStick: (
                gamepad.rightThumbstick.xAxis.value,
                gamepad.rightThumbstick.yAxis.value,
                gamepad.rightThumbstickButton?.isPressed ?? false
            ),
            leftTrigger: gamepad.leftTrigger.value,
            rightTrigger: gamepad.rightTrigger.value
        )
    }

    private func createButtons(_ gamepad: GCExtendedGamepad) -> [ControllerButton] {
        [
            ControllerButton(name: "buttonA", displayName: "Cross (×)", isPressed: gamepad.buttonA.isPressed),
            ControllerButton(name: "buttonB", displayName: "Circle (○)", isPressed: gamepad.buttonB.isPressed),
            ControllerButton(name: "buttonX", displayName: "Square (□)", isPressed: gamepad.buttonX.isPressed),
            ControllerButton(name: "buttonY", displayName: "Triangle (△)", isPressed: gamepad.buttonY.isPressed),
            ControllerButton(name: "leftShoulder", displayName: "L1", isPressed: gamepad.leftShoulder.isPressed),
            ControllerButton(name: "rightShoulder", displayName: "R1", isPressed: gamepad.rightShoulder.isPressed),
            ControllerButton(name: "dpadUp", displayName: "D-Pad Up", isPressed: gamepad.dpad.up.isPressed),
            ControllerButton(name: "dpadDown", displayName: "D-Pad Down", isPressed: gamepad.dpad.down.isPressed),
            ControllerButton(name: "dpadLeft", displayName: "D-Pad Left", isPressed: gamepad.dpad.left.isPressed),
            ControllerButton(name: "dpadRight", displayName: "D-Pad Right", isPressed: gamepad.dpad.right.isPressed)
        ]
    }

    private func setupHandlers(_ gamepad: GCExtendedGamepad) {
        let updateHandler = { [weak self] in
            Task { @MainActor in self?.updateState() }
        }

        // Button handlers
        [gamepad.buttonA, gamepad.buttonB, gamepad.buttonX, gamepad.buttonY,
         gamepad.leftShoulder, gamepad.rightShoulder].forEach {
            $0.pressedChangedHandler = { _, _, _ in updateHandler() }
        }

        // Trigger handlers
        gamepad.leftTrigger.valueChangedHandler = { _, _, _ in updateHandler() }
        gamepad.rightTrigger.valueChangedHandler = { _, _, _ in updateHandler() }

        // Stick handlers
        gamepad.leftThumbstick.valueChangedHandler = { _, _, _ in updateHandler() }
        gamepad.rightThumbstick.valueChangedHandler = { _, _, _ in updateHandler() }
        gamepad.leftThumbstickButton?.pressedChangedHandler = { _, _, _ in updateHandler() }
        gamepad.rightThumbstickButton?.pressedChangedHandler = { _, _, _ in updateHandler() }

        // D-pad handler
        gamepad.dpad.valueChangedHandler = { _, _, _ in updateHandler() }
    }
}

// MARK: - View

struct ControllerDebugView: View {
    @StateObject private var manager = ControllerDebugManager()
    let onClose: (() -> Void)?

    private enum Constants {
        static let stickSize: CGFloat = 40
        static let stickDotSize: CGFloat = 6
        static let stickOffset: CGFloat = 15
        static let triggerSize = CGSize(width: 20, height: 40)
        static let statusDotSize: CGFloat = 8
        static let dpadDotSize: CGFloat = 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if manager.controllerState.isConnected {
                controllerInfoView
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
                .foregroundColor(manager.controllerState.isConnected ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Controller Debug")
                    .font(.headline)
                    .fontWeight(.bold)

                Text(manager.controllerState.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Refresh") { manager.updateState() }
                .buttonStyle(.bordered)
                .font(.caption)

            Button(action: { onClose?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var controllerInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Controller Information")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                infoItem("Name:", manager.controllerState.name)
                infoItem("Vendor:", manager.controllerState.vendorName ?? "Unknown")
                infoItem("Category:", manager.controllerState.productCategory)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var functionGuideView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal Functions Guide")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                // Face buttons
                functionItem("Cross (×)", "Execute command", .green, getButtonState("buttonA"))
                functionItem("Circle (○)", "Clear input", .orange, getButtonState("buttonB"))
                functionItem("Square (□)", "Clear screen", .blue, getButtonState("buttonX"))
                functionItem("Triangle (△)", "Quick commands", .purple, getButtonState("buttonY"))

                // Shoulder buttons
                functionItem("L1", "Previous word", .cyan, getButtonState("leftShoulder"))
                functionItem("R1", "Next word", .cyan, getButtonState("rightShoulder"))

                // Triggers
                triggerItem("L2", "Scroll up", .yellow, manager.controllerState.leftTrigger)
                triggerItem("R2", "Scroll down", .yellow, manager.controllerState.rightTrigger)

                // D-Pad
                dpadItem("D-Pad ↑↓", "Command history", .pink,
                        getButtonState("dpadUp"), getButtonState("dpadDown"))
                dpadItem("D-Pad ←→", "Move cursor", .pink,
                        getButtonState("dpadLeft"), getButtonState("dpadRight"))

                // Sticks
                stickItem("Left Stick", "Cursor control", .mint, manager.controllerState.leftStick)
                stickItem("Right Stick", "Scroll terminal", .mint, manager.controllerState.rightStick)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func getButtonState(_ buttonName: String) -> Bool {
        manager.controllerState.buttons.first { $0.name == buttonName }?.isPressed ?? false
    }

    private func functionItem(_ button: String, _ function: String, _ color: Color, _ isPressed: Bool) -> some View {
        HStack {
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

            Spacer()

            VStack {
                Circle()
                    .fill(isPressed ? .green : .gray.opacity(0.3))
                    .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(isPressed ? 0.2 : 0.1))
        .cornerRadius(8)
    }

    private func triggerItem(_ button: String, _ function: String, _ color: Color, _ pressure: Float) -> some View {
        HStack {
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

            Spacer()

            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(width: Constants.triggerSize.width, height: Constants.triggerSize.height)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(pressure > 0.01 ? .green : .clear)
                            .frame(height: max(0, min(Constants.triggerSize.height, Constants.triggerSize.height * CGFloat(pressure))))
                    }
                )
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(pressure > 0.1 ? 0.2 : 0.1))
        .cornerRadius(8)
    }

    private func dpadItem(_ button: String, _ function: String, _ color: Color, _ isPressed1: Bool, _ isPressed2: Bool) -> some View {
        HStack {
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

            Spacer()

            VStack {
                HStack(spacing: 2) {
                    Circle()
                        .fill(isPressed1 ? .green : .gray.opacity(0.3))
                        .frame(width: Constants.dpadDotSize, height: Constants.dpadDotSize)
                    Circle()
                        .fill(isPressed2 ? .green : .gray.opacity(0.3))
                        .frame(width: Constants.dpadDotSize, height: Constants.dpadDotSize)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity((isPressed1 || isPressed2) ? 0.2 : 0.1))
        .cornerRadius(8)
    }

    private func stickItem(_ button: String, _ function: String, _ color: Color, _ stick: (x: Float, y: Float, pressed: Bool)) -> some View {
        HStack {
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

            Spacer()

            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: Constants.stickSize, height: Constants.stickSize)

                Circle()
                    .fill(stickColor(stick))
                    .frame(width: Constants.stickDotSize, height: Constants.stickDotSize)
                    .offset(
                        x: CGFloat(stick.x) * Constants.stickOffset,
                        y: CGFloat(-stick.y) * Constants.stickOffset
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(stickOpacity(stick)))
        .cornerRadius(8)
    }

    private func stickColor(_ stick: (x: Float, y: Float, pressed: Bool)) -> Color {
        if stick.pressed {
            return .red
        } else if abs(stick.x) > 0.1 || abs(stick.y) > 0.1 {
            return .green
        } else {
            return .gray.opacity(0.5)
        }
    }

    private func stickOpacity(_ stick: (x: Float, y: Float, pressed: Bool)) -> Double {
        stick.pressed || abs(stick.x) > 0.1 || abs(stick.y) > 0.1 ? 0.2 : 0.1
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
}
