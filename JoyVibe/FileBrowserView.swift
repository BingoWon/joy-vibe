//
//  FileBrowserView.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI

/// 现代化文件浏览器视图 - 左右分栏布局
struct FileBrowserView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var fileSystemManager = FileSystemManager()
    @State private var selectedItem: FileSystemItem?
    
    var body: some View {
        NavigationSplitView {
            // 左侧：文件目录树
            fileTreeSidebar
        } detail: {
            // 右侧：文件内容预览
            fileDetailView
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // 初始化时展开第一个根目录
            if let firstRoot = fileSystemManager.rootItems.first {
                firstRoot.toggleExpansion()
            }
        }
    }
    
    // MARK: - 文件目录树侧边栏
    
    private var fileTreeSidebar: some View {
        List(selection: $selectedItem) {
            ForEach(fileSystemManager.rootItems) { rootItem in
                FileTreeNode(item: rootItem, selectedItem: $selectedItem)
            }
        }
        .navigationTitle("Files")
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Control Center") {
                    openWindow(id: "main-control")
                }
                .buttonStyle(.bordered)
                .help("Open main control window")
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            if let item = newItem {
                fileSystemManager.selectItem(item)
            }
        }
    }
    
    // MARK: - 文件详情视图
    
    private var fileDetailView: some View {
        Group {
            if let item = selectedItem {
                FileDetailView(item: item)
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select a file from the sidebar to view its contents")
                )
            }
        }
        .navigationTitle(selectedItem?.name ?? "File Browser")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 文件树节点视图

struct FileTreeNode: View {
    let item: FileSystemItem
    @Binding var selectedItem: FileSystemItem?
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { item.isExpanded },
                set: { _ in item.toggleExpansion() }
            )
        ) {
            // 子节点
            if let children = item.children {
                ForEach(children) { child in
                    if child.isDirectory {
                        FileTreeNode(item: child, selectedItem: $selectedItem)
                    } else {
                        FileLeafNode(item: child, selectedItem: $selectedItem)
                    }
                }
            }
        } label: {
            FileItemLabel(item: item)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItem = item
                }
        }
    }
}

// MARK: - 文件叶子节点视图

struct FileLeafNode: View {
    let item: FileSystemItem
    @Binding var selectedItem: FileSystemItem?
    
    var body: some View {
        FileItemLabel(item: item)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedItem = item
            }
    }
}

// MARK: - 文件项目标签视图

struct FileItemLabel: View {
    let item: FileSystemItem
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                .frame(width: 16)
            
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if !item.isDirectory {
                Text(item.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 文件详情视图

struct FileDetailView: View {
    let item: FileSystemItem
    @State private var fileContent: String = ""
    @State private var isLoading = false
    @State private var loadError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 文件信息头部
            fileInfoHeader
            
            Divider()
            
            // 文件内容或预览
            fileContentView
        }
        .padding()
        .onAppear {
            loadFileContent()
        }
        .onChange(of: item) { _, _ in
            loadFileContent()
        }
    }
    
    // MARK: - 文件信息头部
    
    private var fileInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                    
                    Text(item.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Label(item.formattedSize, systemImage: "externaldrive")
                    .font(.caption)
                
                Spacer()
                
                Label(item.formattedDate, systemImage: "clock")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 文件内容视图
    
    private var fileContentView: some View {
        Group {
            if item.isDirectory {
                directoryContentView
            } else {
                filePreviewView
            }
        }
    }
    
    private var directoryContentView: some View {
        VStack {
            if let children = item.children {
                Text("Directory contains \(children.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Directory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filePreviewView: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                ContentUnavailableView(
                    "Cannot Preview File",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ScrollView {
                    Text(fileContent.isEmpty ? "Empty file" : fileContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - 文件内容加载
    
    private func loadFileContent() {
        guard !item.isDirectory else { return }
        
        isLoading = true
        loadError = nil
        fileContent = ""
        
        Task {
            do {
                // 只预览文本文件
                let textExtensions = ["txt", "md", "swift", "py", "js", "html", "css", "json", "xml", "plist", "log"]
                
                if textExtensions.contains(item.fileExtension) {
                    let content = try String(contentsOf: item.url, encoding: .utf8)
                    
                    await MainActor.run {
                        // 限制显示内容长度
                        if content.count > 10000 {
                            self.fileContent = String(content.prefix(10000)) + "\n\n... (file truncated)"
                        } else {
                            self.fileContent = content
                        }
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.fileContent = "Binary file or unsupported format"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    FileBrowserView()
}
