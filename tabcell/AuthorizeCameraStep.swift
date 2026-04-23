import Foundation
import AVFoundation
import UIKit

/// 相机权限步骤（单文件单职责，自己处理授权逻辑）
struct AuthorizeCameraStep: FlowStep {
    let id: String
    let onStopped: ((PermissionStopContext) -> Void)?
    let onStoppedError: ((FlowError.Permission) -> Void)?
    let autoOpenSettingsWhenStopped: Bool

    var provides: Set<FlowCapability> { [.cameraAuthorized] }

    init(
        id: String = "permission.camera",
        onStopped: ((PermissionStopContext) -> Void)? = nil,
        onStoppedError: ((FlowError.Permission) -> Void)? = nil,
        autoOpenSettingsWhenStopped: Bool = false
    ) {
        self.id = id
        self.onStopped = onStopped
        self.onStoppedError = onStoppedError
        self.autoOpenSettingsWhenStopped = autoOpenSettingsWhenStopped
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        await emitState(.waitingAuthorization(message: "正在请求相机权限"))

        let cameraAvailable = await MainActor.run {
            UIImagePickerController.isSourceTypeAvailable(.camera)
        }
        guard cameraAvailable else {
            return stop(
                .init(
                    feature: .camera,
                    reason: .unavailable,
                    message: "当前设备不支持相机",
                    canOpenSettings: false
                )
            )
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .next
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                return stop(
                    .init(
                        feature: .camera,
                        reason: .permissionDenied,
                        message: "相机权限被拒绝",
                        canOpenSettings: true
                    )
                )
            }
            return .next
        case .denied:
            return stop(
                .init(
                    feature: .camera,
                    reason: .permissionDenied,
                    message: "相机权限被拒绝",
                    canOpenSettings: true
                )
            )
        case .restricted:
            return stop(
                .init(
                    feature: .camera,
                    reason: .restricted,
                    message: "相机权限受限",
                    canOpenSettings: false
                )
            )
        @unknown default:
            return stop(
                .init(
                    feature: .camera,
                    reason: .unavailable,
                    message: "相机权限状态异常",
                    canOpenSettings: false
                )
            )
        }
    }

    private func stop(_ context: PermissionStopContext) -> FlowDirective {
        onStopped?(context)
        onStoppedError?(context.asFlowPermissionError)
        if autoOpenSettingsWhenStopped, context.canOpenSettings {
            AppSettingsNavigator.open()
        }
        return .finish
    }
}
