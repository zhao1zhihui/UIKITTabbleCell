import Foundation
import UserNotifications
import UIKit

/// 通知权限步骤（单文件单职责，自己处理授权逻辑）
struct AuthorizeNotificationStep: FlowStep {
    let id: String
    let onStopped: ((PermissionStopContext) -> Void)?
    let onStoppedError: ((FlowError.Permission) -> Void)?
    let autoOpenSettingsWhenStopped: Bool

    var provides: Set<FlowCapability> { [.notificationAuthorized] }

    init(
        id: String = "permission.notification",
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
        await emitState(.waitingAuthorization(message: "正在请求通知权限"))

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .next
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else {
                    return stop(
                        .init(
                            feature: .notification,
                            reason: .permissionDenied,
                            message: "通知权限被拒绝",
                            canOpenSettings: true
                        )
                    )
                }
                return .next
            } catch {
                return stop(
                    .init(
                        feature: .notification,
                        reason: .unavailable,
                        message: "通知权限申请失败",
                        canOpenSettings: false
                    )
                )
            }
        case .denied:
            return stop(
                .init(
                    feature: .notification,
                    reason: .permissionDenied,
                    message: "通知权限被拒绝",
                    canOpenSettings: true
                )
            )
        @unknown default:
            return stop(
                .init(
                    feature: .notification,
                    reason: .unavailable,
                    message: "通知权限状态异常",
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
