import Foundation
import CoreLocation
import UIKit

/// 定位权限步骤（单文件单职责，自己处理授权逻辑）
struct AuthorizeLocationStep: FlowStep {
    let id: String
    let onStopped: ((PermissionStopContext) -> Void)?
    let autoOpenSettingsWhenStopped: Bool

    init(
        id: String = "permission.location",
        onStopped: ((PermissionStopContext) -> Void)? = nil,
        autoOpenSettingsWhenStopped: Bool = false
    ) {
        self.id = id
        self.onStopped = onStopped
        self.autoOpenSettingsWhenStopped = autoOpenSettingsWhenStopped
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        await emitState(.waitingAuthorization(message: "正在请求定位权限"))

        guard CLLocationManager.locationServicesEnabled() else {
            return stop(
                .init(
                    feature: .location,
                    reason: .servicesDisabled,
                    message: "系统定位服务未开启",
                    canOpenSettings: false
                )
            )
        }

        let agent = LocationAuthorizationAgent()
        switch agent.currentStatus {
        case .authorized:
            return .next
        case .notDetermined:
            let result = await agent.requestWhenInUseAuthorization()
            guard result == .authorized else {
                return stop(
                    .init(
                        feature: .location,
                        reason: .permissionDenied,
                        message: "定位权限被拒绝",
                        canOpenSettings: true
                    )
                )
            }
            return .next
        case .denied:
            return stop(
                .init(
                    feature: .location,
                    reason: .permissionDenied,
                    message: "定位权限被拒绝",
                    canOpenSettings: true
                )
            )
        case .restricted:
            return stop(
                .init(
                    feature: .location,
                    reason: .restricted,
                    message: "定位权限受限",
                    canOpenSettings: false
                )
            )
        }
    }

    private func stop(_ context: PermissionStopContext) -> FlowDirective {
        onStopped?(context)
        if autoOpenSettingsWhenStopped, context.canOpenSettings {
            AppSettingsNavigator.open()
        }
        return .finish
    }
}

private enum LocationAuthorizationState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

private final class LocationAuthorizationAgent: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<LocationAuthorizationState, Never>?

    var currentStatus: LocationAuthorizationState {
        switch manager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorizationState {
        switch currentStatus {
        case .authorized, .denied, .restricted:
            return currentStatus
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }
        let mapped = currentStatus
        guard mapped != .notDetermined else { return }
        self.continuation = nil
        continuation.resume(returning: mapped)
    }
}
