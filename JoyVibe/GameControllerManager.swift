//
//  GameControllerManager.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI
import GameController
import CoreHaptics

/// PS5手柄管理器 - 专为终端界面设计的游戏化控制体验
@Observable
class GameControllerManager {
    static let shared = GameControllerManager()
    
    // 手柄状态
    var isControllerConnected = false
    var connectedController: GCController?
    var controllerName: String = ""
    
    // 触觉反馈引擎
    private var hapticEngine: CHHapticEngine?
    
    // 终端控制状态
    var cursorPosition: Int = 0
    var isInCommandMode = false
    var commandHistoryIndex = -1
    
    // 回调闭包
    var onControllerConnected: ((GCController) -> Void)?
    var onControllerDisconnected: (() -> Void)?
    var onButtonPressed: ((String) -> Void)?
    var onLeftStickMoved: ((Float, Float) -> Void)?
    var onRightStickMoved: ((Float, Float) -> Void)?
    var onDPadPressed: ((String) -> Void)?
    
    private init() {
        setupControllerObservers()
        setupHapticEngine()
        checkForExistingControllers()
    }
    
    // MARK: - 手柄连接管理
    
    private func setupControllerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }
    
    private func checkForExistingControllers() {
        if let controller = GCController.controllers().first {
            handleControllerConnection(controller)
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        handleControllerConnection(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        handleControllerDisconnection()
    }
    
    private func handleControllerConnection(_ controller: GCController) {
        connectedController = controller
        isControllerConnected = true
        controllerName = controller.vendorName ?? "Game Controller"

        setupControllerInputHandlers(controller)
        onControllerConnected?(controller)
        playHapticFeedback(.success)
    }
    
    private func handleControllerDisconnection() {
        connectedController = nil
        isControllerConnected = false
        controllerName = ""
        onControllerDisconnected?()
    }
    
    // MARK: - 手柄输入处理
    
    private func setupControllerInputHandlers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // 按钮映射
        gamepad.buttonA.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("A")
            self?.playHapticFeedback(.light)
        }

        gamepad.buttonB.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("B")
            self?.playHapticFeedback(.light)
        }

        gamepad.buttonX.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("X")
            self?.playHapticFeedback(.medium)
        }

        gamepad.buttonY.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("Y")
            self?.playHapticFeedback(.light)
        }
        
        // 方向键
        gamepad.dpad.up.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onDPadPressed?("up")
            self?.playHapticFeedback(.selection)
        }

        gamepad.dpad.down.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onDPadPressed?("down")
            self?.playHapticFeedback(.selection)
        }

        gamepad.dpad.left.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onDPadPressed?("left")
            self?.playHapticFeedback(.selection)
        }

        gamepad.dpad.right.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onDPadPressed?("right")
            self?.playHapticFeedback(.selection)
        }
        
        // 摇杆
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, xValue, yValue) in
            self?.onLeftStickMoved?(xValue, yValue)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, xValue, yValue) in
            self?.onRightStickMoved?(xValue, yValue)
        }

        // 肩部按钮
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("L1")
            self?.playHapticFeedback(.light)
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] (_, _, pressed) in
            guard pressed else { return }
            self?.onButtonPressed?("R1")
            self?.playHapticFeedback(.light)
        }
    }
    
    // MARK: - 触觉反馈
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            // 触觉反馈失败不影响核心功能
        }
    }
    
    enum HapticFeedbackType {
        case light, medium, heavy, success, error, selection
    }
    
    func playHapticFeedback(_ type: HapticFeedbackType) {
        guard let engine = hapticEngine else { return }
        
        var events: [CHHapticEvent] = []
        
        switch type {
        case .light:
            events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0)]
            
        case .medium:
            events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0)]
            
        case .heavy:
            events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0)]
            
        case .success:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0.1)
            ]
            
        case .error:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.05),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0.1)
            ]
            
        case .selection:
            events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0)]
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // 触觉反馈播放失败不影响核心功能
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hapticEngine?.stop()
    }
}
