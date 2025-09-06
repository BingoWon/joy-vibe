//
//  JoyVibeApp.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

@main
struct JoyVibeApp: App {

    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()

    init() {
        logger.info("应用启动")
    }
    
    var body: some Scene {
        // 主控制窗口 - 应用启动时显示，以 Zed Connection 为核心
        WindowGroup("JoyVibe", id: "main-control") {
            MainControlView()
                .environment(appModel)
        }
        .defaultSize(width: 800, height: 900)
        .windowResizability(.contentSize)

        // 终端窗口 - 通过主控制窗口手动打开
        WindowGroup("Terminal", id: "terminal") {
            TerminalView()
        }
        .defaultSize(width: 1000, height: 700)

        // 文件浏览器窗口 - 通过主控制窗口手动打开
        WindowGroup("File Browser", id: "file-browser") {
            FileBrowserView()
        }
        .defaultSize(width: 1000, height: 700)

        // 沉浸式空间
        ImmersiveSpace(id: "immersive-space") {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
