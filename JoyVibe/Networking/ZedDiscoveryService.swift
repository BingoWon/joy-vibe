//
//  ZedDiscoveryService.swift
//  JoyVibe
//
//  Created by AI Assistant on 2025-09-06.
//

import Foundation
import Network
import Combine

#if canImport(Darwin)
import Darwin
#endif

/// 现代化 HTTP 发现服务
@MainActor
final class ZedDiscoveryService: ObservableObject {
    @Published private(set) var discoveredServices: [ZedService] = []
    @Published private(set) var isScanning = false
    @Published private(set) var error: String?
    
    private let urlSession: URLSession
    private var scanTask: Task<Void, Never>?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 5.0
        self.urlSession = URLSession(configuration: config)
    }
    
    deinit {
        scanTask?.cancel()
    }
    
    /// 开始扫描 Zed 服务
    func startScanning() {
        guard !isScanning else { return }
        
        error = nil
        isScanning = true
        discoveredServices.removeAll()
        
        scanTask = Task {
            await scanForZedServices()
        }
    }
    
    /// 停止扫描
    func stopScanning() {
        guard isScanning else { return }
        
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    /// 智能扫描局域网中的 Zed 服务
    private func scanForZedServices() async {
        let smartIPs = generateSmartIPs()

        // 限制并发扫描数量以提高性能
        await withTaskGroup(of: ZedService?.self) { group in
            var activeScans = 0
            let maxConcurrentScans = 50

            for ip in smartIPs {
                if activeScans >= maxConcurrentScans {
                    // 等待一个任务完成
                    if let service = await group.next() {
                        if let service = service {
                            discoveredServices.append(service)
                        }
                        activeScans -= 1
                    }
                }

                group.addTask {
                    await self.checkZedService(at: ip)
                }
                activeScans += 1
            }

            // 收集剩余结果
            for await service in group {
                if let service = service {
                    discoveredServices.append(service)
                }
            }
        }

        isScanning = false

        if discoveredServices.isEmpty {
            error = "No Zed instances found. Make sure Zed is running with ZedVision enabled."
        }
    }
    
    /// 检查指定 IP 是否有 Zed 服务
    private func checkZedService(at ip: String) async -> ZedService? {
        let discoveryURL = URL(string: "http://\(ip):8766/discover")!
        
        do {
            let (data, response) = try await urlSession.data(from: discoveryURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let serviceInfo = try JSONDecoder().decode(ZedServiceInfo.self, from: data)
            
            return ZedService(
                name: serviceInfo.name,
                host: ip,
                port: 8765, // WebSocket 端口
                version: serviceInfo.version,
                platform: serviceInfo.platform,
                app: serviceInfo.app
            )
            
        } catch {
            // 静默忽略连接失败，这是正常的
            return nil
        }
    }
    
    /// 智能生成 IP 地址列表，优先扫描当前网段
    private func generateSmartIPs() -> [String] {
        var ips: [String] = []

        // 1. 获取当前设备的 IP 地址和网段
        if let currentIP = getCurrentDeviceIP() {
            let networkSegment = getNetworkSegment(from: currentIP)

            // 2. 优先扫描当前网段
            for i in 1...254 {
                ips.append("\(networkSegment).\(i)")
            }
        }

        // 3. 添加常见的其他网段（限制数量）
        let commonSegments = ["192.168.1", "192.168.0", "10.0.0", "172.16.0"]
        for segment in commonSegments {
            // 只扫描每个网段的前50个地址以提高速度
            for i in 1...50 {
                let ip = "\(segment).\(i)"
                if !ips.contains(ip) {
                    ips.append(ip)
                }
            }
        }

        return ips
    }

    /// 获取当前设备的 IP 地址
    private func getCurrentDeviceIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" { // WiFi or Ethernet
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    /// 从 IP 地址提取网段
    private func getNetworkSegment(from ip: String) -> String {
        let components = ip.split(separator: ".")
        if components.count >= 3 {
            return "\(components[0]).\(components[1]).\(components[2])"
        }
        return "192.168.1" // 默认网段
    }
}

/// Zed 服务发现响应
private struct ZedServiceInfo: Codable {
    let name: String
    let websocket_url: String
    let version: String
    let platform: String
    let app: String
}
