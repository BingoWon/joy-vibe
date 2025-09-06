//
//  WindowManager.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

/// 现代化窗口管理器
@Observable
final class WindowManager {
    static let shared = WindowManager()

    var isTerminalOpen = false
    var isFileBrowserOpen = false
    var isImmersiveSpaceOpen = false
    var isFirstLaunch = true

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
    

}
