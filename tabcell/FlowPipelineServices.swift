import Foundation
import UIKit
import CoreLocation

// MARK: - 基础类型

enum CameraMode {
    case system
    case custom
}

struct FlowUploadResponse {
    let requestID: String
    let message: String
}

/// 权限节点类型
enum PermissionFeature {
    case camera
    case location
}

/// 权限节点中止原因（中止是“受控结束”，不一定是异常）
enum PermissionStopReason {
    case servicesDisabled
    case permissionDenied
    case restricted
    case unavailable
}

/// 权限节点中止回调上下文
struct PermissionStopContext {
    let feature: PermissionFeature
    let reason: PermissionStopReason
    let message: String
    let canOpenSettings: Bool
}

// MARK: - 协议定义（方便测试和替换实现）

protocol CameraService {
    func openCamera(mode: CameraMode) async throws -> UIImage
}

protocol LocationService {
    func requestOneShotLocation() async throws -> CLLocation
}

protocol FlowNetworkService {
    func upload(image: UIImage?, location: CLLocation?) async throws -> FlowUploadResponse
}

/// 打开 App 设置页（给权限节点复用）
enum AppSettingsNavigator {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 相机服务（示例实现）

/// 示例相机服务：
/// - 保留 system/custom 两种模式接口
/// - 这里用本地生成图片模拟，项目里可替换为真实相机实现
final class DemoCameraService: CameraService {
    func openCamera(mode: CameraMode) async throws -> UIImage {
        try? await Task.sleep(nanoseconds: 150_000_000)

        let title: String
        let color: UIColor
        switch mode {
        case .system:
            title = "System Camera"
            color = .systemBlue
        case .custom:
            title = "Custom Camera"
            color = .systemOrange
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let text = NSString(string: title)
            text.draw(at: CGPoint(x: 40, y: 260), withAttributes: attrs)
        }
    }
}

// MARK: - 定位服务实现

final class CoreLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestOneShotLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}

// MARK: - 网络服务示例

final class DemoFlowNetworkService: FlowNetworkService {
    func upload(image: UIImage?, location: CLLocation?) async throws -> FlowUploadResponse {
        try? await Task.sleep(nanoseconds: 400_000_000)
        let requestID = UUID().uuidString
        let hasImage = image != nil
        let hasLocation = location != nil
        return FlowUploadResponse(
            requestID: requestID,
            message: "上传成功(image=\(hasImage), location=\(hasLocation))"
        )
    }
}
