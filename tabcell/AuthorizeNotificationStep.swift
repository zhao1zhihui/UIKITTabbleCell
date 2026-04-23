import Foundation
import UserNotifications
import UIKit

/// 通知权限步骤（单文件单职责，自己处理授权逻辑）
struct AuthorizeNotificationStep: FlowStep {
    let id: String
    let openSettingsIfDenied: Bool

    init(
        id: String = "permission.notification",
        openSettingsIfDenied: Bool = false
    ) {
        self.id = id
        self.openSettingsIfDenied = openSettingsIfDenied
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
                    if openSettingsIfDenied { openSystemSettings() }
                    throw FlowError.authorizationDenied(message: "通知权限被拒绝")
                }
                return .next
            } catch {
                if openSettingsIfDenied { openSystemSettings() }
                throw FlowError.authorizationRequestFailed(message: "通知权限申请失败")
            }
        case .denied:
            if openSettingsIfDenied { openSystemSettings() }
            throw FlowError.authorizationDenied(message: "通知权限被拒绝")
        @unknown default:
            if openSettingsIfDenied { openSystemSettings() }
            throw FlowError.authorizationRequestFailed(message: "通知权限状态异常")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
