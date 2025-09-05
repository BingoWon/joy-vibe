//
//  JoyVibeLogger.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import os
import Foundation

/// 现代化的JoyVibe日志系统 - 全局最优解
/// 使用Swift 5.9+ Logger API，零冗余设计
final class JoyVibeLogger: Sendable {

    // MARK: - 配置常量
    private static let subsystem = "Bin.JoyVibe"
    private static let logPrefix = "🎮[JoyVibe]"

    // MARK: - 现代化日志分类
    enum Category: String, CaseIterable, Sendable {
        case arkit = "ARKit"
        case ui = "UI"
        case terminal = "Terminal"
        case system = "System"

        var logger: Logger {
            Logger(subsystem: JoyVibeLogger.subsystem, category: self.rawValue)
        }
    }

    // MARK: - 单例
    static let shared = JoyVibeLogger()

    // MARK: - ARKit性能优化
    private let arkitThrottle = ThrottleManager(interval: 0.2, sampleRate: 20)

    private init() {}

    // MARK: - 现代化日志接口

    /// 调试日志
    func debug(_ message: String, category: Category = .system) {
        category.logger.debug("\(Self.logPrefix) 🔍 \(message)")
    }

    /// 信息日志
    func info(_ message: String, category: Category = .system) {
        category.logger.info("\(Self.logPrefix) ℹ️ \(message)")
    }

    /// 警告日志
    func warning(_ message: String, category: Category = .system) {
        category.logger.warning("\(Self.logPrefix) ⚠️ \(message)")
    }

    /// 错误日志
    func error(_ message: String, category: Category = .system) {
        category.logger.error("\(Self.logPrefix) ❌ \(message)")
    }

    // MARK: - ARKit专用优化日志

    /// ARKit调试日志（带智能节流）
    func arkitDebug(_ message: String) {
        guard arkitThrottle.shouldLog() else { return }
        debug(message, category: .arkit)
    }

    /// ARKit信息日志（带智能节流）
    func arkitInfo(_ message: String) {
        guard arkitThrottle.shouldLog() else { return }
        info(message, category: .arkit)
    }

    /// ARKit错误日志（不节流）
    func arkitError(_ message: String) {
        error(message, category: .arkit)
    }
}

// MARK: - 高性能节流管理器

private final class ThrottleManager: Sendable {
    private let interval: TimeInterval
    private let sampleRate: Int
    private let lock = NSLock()
    private var lastLogTime: TimeInterval = 0
    private var counter: Int = 0

    init(interval: TimeInterval, sampleRate: Int) {
        self.interval = interval
        self.sampleRate = sampleRate
    }

    func shouldLog() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let currentTime = CFAbsoluteTimeGetCurrent()
        counter += 1

        // 时间节流
        guard currentTime - lastLogTime >= interval else { return false }

        // 采样节流
        guard counter % sampleRate == 0 else { return false }

        lastLogTime = currentTime
        return true
    }
}

// MARK: - 全局日志实例

/// 全局日志实例 - 现代化单一接口
let logger = JoyVibeLogger.shared
