//
//  WindowManager.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

/// 窗口管理器 - 控制应用的窗口状态和行为
@Observable
class WindowManager {
    static let shared = WindowManager()
    
    // 窗口状态
    var isTerminalOpen = false
    var isFileBrowserOpen = false
    var isImmersiveSpaceOpen = false
    
    // 应用启动状态
    var isFirstLaunch = true
    var shouldShowMainControl = true
    
    private init() {}
    
    /// 标记应用已完成首次启动
    func markFirstLaunchComplete() {
        isFirstLaunch = false
    }
    
    /// 打开终端窗口
    func openTerminal() {
        isTerminalOpen = true
    }
    
    /// 关闭终端窗口
    func closeTerminal() {
        isTerminalOpen = false
    }
    
    /// 打开文件浏览器窗口
    func openFileBrowser() {
        isFileBrowserOpen = true
    }
    
    /// 关闭文件浏览器窗口
    func closeFileBrowser() {
        isFileBrowserOpen = false
    }
    
    /// 打开沉浸式空间
    func openImmersiveSpace() {
        isImmersiveSpaceOpen = true
    }
    
    /// 关闭沉浸式空间
    func closeImmersiveSpace() {
        isImmersiveSpaceOpen = false
    }
    
    /// 计算打开的窗口数量
    var openWindowsCount: Int {
        var count = 0
        if isTerminalOpen { count += 1 }
        if isFileBrowserOpen { count += 1 }
        return count
    }
    
    /// 获取活跃窗口列表
    var activeWindowsList: String {
        var windows: [String] = []
        if isTerminalOpen { windows.append("Terminal") }
        if isFileBrowserOpen { windows.append("File Browser") }
        return windows.joined(separator: ", ")
    }
}
