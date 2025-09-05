//
//  FileSystemItem.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import Foundation
import SwiftUI

/// 文件系统项目模型 - 支持层级结构的文件和文件夹
@Observable
class FileSystemItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileSystemItem]?
    var isExpanded: Bool = false
    
    // 文件属性
    var size: Int64 = 0
    var modificationDate: Date = Date()
    var fileExtension: String = ""
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        var isDir: ObjCBool = false
        self.isDirectory = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        
        if isDirectory {
            self.children = []
        }
        
        loadFileAttributes()
    }
    
    /// 加载文件属性
    private func loadFileAttributes() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.size = attributes[.size] as? Int64 ?? 0
            self.modificationDate = attributes[.modificationDate] as? Date ?? Date()
            self.fileExtension = url.pathExtension.lowercased()
        } catch {
            // 忽略错误，使用默认值
        }
    }
    
    /// 懒加载子项目
    func loadChildren() {
        guard isDirectory, children?.isEmpty == true else { return }
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            self.children = urls
                .map { FileSystemItem(url: $0) }
                .sorted { item1, item2 in
                    // 文件夹优先，然后按名称排序
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                }
        } catch {
            logger.error("加载子项目失败 \(url.path): \(error.localizedDescription)")
            self.children = []
        }
    }
    
    /// 切换展开状态
    func toggleExpansion() {
        if isDirectory {
            isExpanded.toggle()
            if isExpanded {
                loadChildren()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// 显示图标
    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        } else {
            return iconForFileExtension(fileExtension)
        }
    }
    
    /// 格式化的文件大小
    var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 格式化的修改日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    // MARK: - Private Methods
    
    private func iconForFileExtension(_ ext: String) -> String {
        switch ext {
        case "txt", "md", "rtf":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        case "mp4", "mov", "avi", "mkv":
            return "video"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "swift", "py", "js", "html", "css", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "plist":
            return "doc.text.below.ecg"
        default:
            return "doc"
        }
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FileSystemManager

/// 文件系统管理器
@Observable
class FileSystemManager {
    var rootItems: [FileSystemItem] = []
    var selectedItem: FileSystemItem?
    
    init() {
        loadRootItems()
    }
    
    /// 加载根目录项目
    private func loadRootItems() {
        // visionOS 中使用可用的目录
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())

        var candidateURLs = [
            documentsURL,
            cachesURL,
            libraryURL,
            tempURL
        ]

        // 尝试添加应用支持目录
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidateURLs.append(appSupportURL)
        }

        rootItems = candidateURLs.compactMap { url in
            // 只包含存在的目录
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                return FileSystemItem(url: url)
            }
            return nil
        }
    }
    
    /// 选择文件项目
    func selectItem(_ item: FileSystemItem) {
        selectedItem = item
    }
}
