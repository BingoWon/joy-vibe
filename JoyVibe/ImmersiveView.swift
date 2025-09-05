//
//  ImmersiveView.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @State private var arkitSession = ARKitSession()
    @State private var worldTrackingProvider = WorldTrackingProvider()
    @State private var sceneReconstructionProvider = SceneReconstructionProvider(modes: [.classification])
    @State private var meshEntities: [UUID: Entity] = [:]
    @State private var updateTrigger = 0

    // 终端界面交互状态
    @State private var terminalPosition: SIMD3<Float> = [0, 1.0, -2.0]
    @State private var terminalScale: Float = 1.0
    @GestureState private var dragOffset: SIMD3<Float> = .zero
    @GestureState private var magnifyScale: Float = 1.0

    var body: some View {
        RealityView { content, attachments in
            setupSimpleScene(content: content)

            // 添加终端界面作为 3D 空间中的附件
            if let terminalAttachment = attachments.entity(for: "terminal") {
                updateTerminalTransform(terminalAttachment)
                content.add(terminalAttachment)
                logger.info("终端界面已添加到3D空间", category: .arkit)
            }

            logger.info("RealityView内容设置完成", category: .arkit)
        } update: { content, attachments in
            updateSceneReconstruction(content: content)

            // 更新终端位置和缩放
            if let terminalAttachment = attachments.entity(for: "terminal") {
                updateTerminalTransform(terminalAttachment)
            }

            logger.debug("RealityView更新触发 (计数: \(updateTrigger))", category: .arkit)
        } attachments: {
            Attachment(id: "terminal") {
                InteractiveTerminalView(
                    position: $terminalPosition,
                    scale: $terminalScale
                )
                .frame(width: 600, height: 400)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .scaleEffect(CGFloat(terminalScale * magnifyScale))
                .gesture(terminalDragGesture)
                .gesture(terminalMagnifyGesture)
            }
        }
        .task {
            await startARKitSession()
        }
        .task {
            await processSceneUpdates()
        }
        .onAppear {
            logger.info("沉浸式视图已启动", category: .arkit)
        }
    }

    // MARK: - 终端交互手势

    private var terminalDragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, gestureState, transaction in
                // 使用 3D 拖动偏移
                let translation3D = value.translation3D
                gestureState = SIMD3<Float>(
                    Float(translation3D.x) * 0.001, // 转换为米
                    Float(translation3D.y) * 0.001,
                    Float(translation3D.z) * 0.001
                )
            }
            .onEnded { value in
                // 更新终端位置
                let translation3D = value.translation3D
                let deltaPosition = SIMD3<Float>(
                    Float(translation3D.x) * 0.001,
                    Float(translation3D.y) * 0.001,
                    Float(translation3D.z) * 0.001
                )
                terminalPosition += deltaPosition
                logger.debug("终端移动到位置: \(terminalPosition)", category: .ui)
            }
    }

    private var terminalMagnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyScale) { value, gestureState, transaction in
                gestureState = Float(value.magnification)
            }
            .onEnded { value in
                // 更新终端缩放
                terminalScale *= Float(value.magnification)
                // 限制缩放范围
                terminalScale = max(0.5, min(terminalScale, 3.0))
                logger.debug("终端缩放至: \(String(format: "%.2f", terminalScale))", category: .ui)
            }
    }

    private func updateTerminalTransform(_ entity: Entity) {
        let finalPosition = terminalPosition + dragOffset
        entity.position = finalPosition
        logger.debug("终端变换已更新 - 位置: \(finalPosition), 缩放: \(String(format: "%.2f", terminalScale))", category: .ui)
    }

    private func setupSimpleScene(content: RealityViewContent) {
        logger.info("开始设置线框可视化场景", category: .arkit)

        // 添加状态指示文字
        let textMesh = MeshResource.generateText(
            "JoyVibe Terminal Active\n\nTerminal ready for commands\nEnvironment scanning active",
            extrusionDepth: 0.02,
            font: .systemFont(ofSize: 0.06),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: .white)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [0, 2.0, -1.5]
        content.add(textEntity)
        logger.info("状态文本已添加，环境扫描准备就绪", category: .arkit)

        logger.info("场景设置完成，等待ARKit网格数据", category: .arkit)
    }

    private func startARKitSession() async {
        logger.info("启动ARKit会话", category: .arkit)

        do {
            if SceneReconstructionProvider.isSupported {
                logger.info("场景重建提供器已支持", category: .arkit)
                logger.debug("场景重建模式: \(sceneReconstructionProvider.modes)", category: .arkit)

                try await arkitSession.run([worldTrackingProvider, sceneReconstructionProvider])
                logger.info("ARKit会话启动成功，场景重建已启用", category: .arkit)
                logger.info("开始监听网格锚点", category: .arkit)
            } else {
                logger.error("此设备不支持场景重建", category: .arkit)
                try await arkitSession.run([worldTrackingProvider])
            }
        } catch {
            logger.error("ARKit会话启动失败: \(error.localizedDescription)", category: .arkit)
        }
    }

    private func updateSceneReconstruction(content: RealityViewContent) {
        // 获取当前场景中的所有网格实体
        let currentMeshEntities = content.entities.filter { $0.name.starts(with: "mesh_") }

        // 处理每个网格实体
        for (anchorId, newEntity) in meshEntities {
            let entityName = "mesh_\(anchorId)"

            // 查找是否已存在该锚点的实体
            if let existingEntity = currentMeshEntities.first(where: { $0.name == entityName }) {
                // 如果存在，替换为新的实体（处理更新情况）
                content.remove(existingEntity)
                newEntity.name = entityName
                content.add(newEntity)
                logger.arkitDebug("网格实体已更新: \(anchorId.uuidString.prefix(8))...")
            } else {
                // 如果不存在，添加新实体
                newEntity.name = entityName
                content.add(newEntity)
                logger.arkitDebug("新网格实体已添加: \(anchorId.uuidString.prefix(8))...")
            }
        }

        // 移除不再存在的网格实体
        for entity in currentMeshEntities {
            let name = entity.name
            if let anchorIdString = name.components(separatedBy: "_").last,
               let anchorId = UUID(uuidString: anchorIdString),
               meshEntities[anchorId] == nil {
                content.remove(entity)
                logger.arkitDebug("网格实体已移除: \(anchorId.uuidString.prefix(8))...")
            }
        }
    }

    private func processSceneUpdates() async {
        guard SceneReconstructionProvider.isSupported else {
            logger.error("此设备不支持场景重建", category: .arkit)
            return
        }

        logger.info("开始场景重建更新", category: .arkit)

        // 处理场景重建更新
        for await update in sceneReconstructionProvider.anchorUpdates {
            await MainActor.run {
                switch update.event {
                case .added:
                    logger.arkitInfo("网格锚点已添加: \(update.anchor.id.uuidString.prefix(8))...")
                    let meshEntity = createWireframeMeshVisualization(from: update.anchor)
                    meshEntities[update.anchor.id] = meshEntity
                    updateTrigger += 1

                case .updated:
                    logger.arkitDebug("网格锚点已更新: \(update.anchor.id.uuidString.prefix(8))...")
                    let updatedEntity = createWireframeMeshVisualization(from: update.anchor)
                    meshEntities[update.anchor.id] = updatedEntity
                    updateTrigger += 1

                case .removed:
                    logger.arkitInfo("网格锚点已移除: \(update.anchor.id.uuidString.prefix(8))...")
                    meshEntities.removeValue(forKey: update.anchor.id)
                    updateTrigger += 1
                }
            }
        }
    }



    private func createWireframeMeshVisualization(from anchor: MeshAnchor) -> Entity {
        let entity = Entity()
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        // 获取真实的网格几何数据
        let meshGeometry = anchor.geometry

        let triangleCount = meshGeometry.faces.count / 3
        let ratio = Float(meshGeometry.vertices.count) / Float(max(triangleCount, 1))
        logger.arkitDebug("网格数据 \(anchor.id.uuidString.prefix(8))... - 顶点:\(meshGeometry.vertices.count) 三角形:\(triangleCount) 比率:\(String(format: "%.2f", ratio))")

        // 提取顶点数据
        let vertexBuffer = meshGeometry.vertices.buffer
        let vertexCount = meshGeometry.vertices.count
        let vertexStride = meshGeometry.vertices.stride

        var vertices: [SIMD3<Float>] = []
        for i in 0..<vertexCount {
            let offset = i * vertexStride
            let vertexPointer = vertexBuffer.contents().advanced(by: offset)
            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            vertices.append(vertex)
        }

        // 提取面数据
        let faceBuffer = meshGeometry.faces.buffer
        let faceCount = meshGeometry.faces.count

        var faces: [UInt32] = []
        let facePointer = faceBuffer.contents().assumingMemoryBound(to: UInt32.self)
        for i in 0..<faceCount {
            faces.append(facePointer[i])
        }

        logger.debug("提取顶点: \(vertices.count), 面索引: \(faces.count)", category: .arkit)

        // 检查网格连续性
        let meshQuality = analyzeMeshQuality(vertices: vertices, faces: faces)
        logger.debug("网格质量分析: \(meshQuality)", category: .arkit)

        // 创建明显的线框网格
        if !vertices.isEmpty && !faces.isEmpty {
            let wireframeEntity = createBrightWireframeMesh(vertices: vertices, faces: faces)
            entity.addChild(wireframeEntity)
            logger.debug("增强线框网格已创建: \(anchor.id.uuidString.prefix(8))...", category: .arkit)
        } else {
            logger.warning("锚点无网格数据: \(anchor.id.uuidString.prefix(8))...", category: .arkit)
        }

        return entity
    }

    private func createBrightWireframeMesh(vertices: [SIMD3<Float>], faces: [UInt32]) -> Entity {
        // 创建线框实体
        let wireframeEntity = Entity()

        logger.debug("创建增强线框网格，提升可见性", category: .arkit)

        // 直接使用原始网格数据创建线框
        if !vertices.isEmpty && !faces.isEmpty {
            do {
                var meshDescriptor = MeshDescriptor()
                meshDescriptor.positions = MeshBuffer(vertices)
                meshDescriptor.primitives = .triangles(faces)

                let mesh = try MeshResource.generate(from: [meshDescriptor])

                // 创建增强的线框材质
                var wireframeMaterial = UnlitMaterial()
                wireframeMaterial.color = .init(tint: .green) // 使用绿色，更符合传统 wireframe 颜色
                wireframeMaterial.blending = .transparent(opacity: 0.9) // 稍微透明，避免过于刺眼

                // 启用线框渲染模式
                wireframeMaterial.triangleFillMode = .lines

                let modelEntity = ModelEntity(mesh: mesh, materials: [wireframeMaterial])
                wireframeEntity.addChild(modelEntity)

                // 添加第二层半透明填充，帮助识别网格的连续性
                var fillMaterial = UnlitMaterial()
                fillMaterial.color = .init(tint: .green)
                fillMaterial.blending = .transparent(opacity: 0.1) // 非常透明的填充
                fillMaterial.triangleFillMode = .fill

                let fillEntity = ModelEntity(mesh: mesh, materials: [fillMaterial])
                wireframeEntity.addChild(fillEntity)

                logger.debug("增强线框网格已创建，包含填充覆盖", category: .arkit)

            } catch {
                logger.error("线框网格创建失败: \(error.localizedDescription)", category: .arkit)
            }
        }

        return wireframeEntity
    }

    private func analyzeMeshQuality(vertices: [SIMD3<Float>], faces: [UInt32]) -> String {
        guard !vertices.isEmpty && !faces.isEmpty else {
            return "Empty mesh"
        }

        let triangleCount = faces.count / 3
        let vertexCount = vertices.count

        // 计算边界框来了解网格大小
        var minPoint = vertices[0]
        var maxPoint = vertices[0]

        for vertex in vertices {
            minPoint = SIMD3<Float>(
                min(minPoint.x, vertex.x),
                min(minPoint.y, vertex.y),
                min(minPoint.z, vertex.z)
            )
            maxPoint = SIMD3<Float>(
                max(maxPoint.x, vertex.x),
                max(maxPoint.y, vertex.y),
                max(maxPoint.z, vertex.z)
            )
        }

        let size = maxPoint - minPoint
        let volume = size.x * size.y * size.z

        // 检查是否有退化三角形（面积为0的三角形）
        var degenerateTriangles = 0
        for i in stride(from: 0, to: faces.count, by: 3) {
            guard i + 2 < faces.count else { break }

            let v0Index = Int(faces[i])
            let v1Index = Int(faces[i + 1])
            let v2Index = Int(faces[i + 2])

            guard v0Index < vertices.count, v1Index < vertices.count, v2Index < vertices.count else {
                continue
            }

            let v0 = vertices[v0Index]
            let v1 = vertices[v1Index]
            let v2 = vertices[v2Index]

            // 计算三角形面积
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let crossProduct = cross(edge1, edge2)
            let area = length(crossProduct) * 0.5

            if area < 0.0001 { // 非常小的面积认为是退化三角形
                degenerateTriangles += 1
            }
        }

        let qualityScore = Float(triangleCount - degenerateTriangles) / Float(max(triangleCount, 1)) * 100

        return String(format: "Triangles: %d, Degenerate: %d, Quality: %.1f%%, Size: %.2fx%.2fx%.2f",
                     triangleCount, degenerateTriangles, qualityScore, size.x, size.y, size.z)
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
