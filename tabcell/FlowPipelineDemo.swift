import Foundation
import UIKit
import CoreLocation

/*
 流水线示例（简化流程图）

 [开始]
   |
   v
 [AuthorizeCameraStep]
   |
   v
 [CaptureImageStep] --(回调图片)-->
   |
   v
 [AuthorizeLocationStep]
   |
   v
 [FetchLocationStep] --(回调定位)-->
   |
   v
 [UploadStep] <--(provider读取图片/定位)--
   |
   v
 [结束]

 异常分支：
 - 权限拒绝 -> finish（通过 onStopped / onStoppedError 回传）
 - 任意 Step 抛错 -> failed
 - 外部 cancel -> cancelled
 */

/// 对外示例入口：协调器只做调度，数据通过 Step 回调/Provider 传递。
enum FlowPipelineDemoFactory {
    @MainActor
    static func makeCoordinator() -> FlowCoordinator {
        FlowCoordinator(interceptors: [FlowLogInterceptor()])
    }

    /// 默认流程：相机权限 -> 拍照 -> 定位权限 -> 定位 -> 上传
    static func defaultSteps(
        onCameraPermissionStopped: ((PermissionStopContext) -> Void)? = nil,
        onLocationPermissionStopped: ((PermissionStopContext) -> Void)? = nil,
        onCameraPermissionError: ((FlowError.Permission) -> Void)? = nil,
        onLocationPermissionError: ((FlowError.Permission) -> Void)? = nil,
        autoOpenSettingsWhenPermissionStopped: Bool = false,
        onUploaded: ((FlowUploadResponse) -> Void)? = nil
    ) -> [AnyFlowStep] {
        let cameraService = DemoCameraService()
        let locationService = CoreLocationService()
        let networkService = DemoFlowNetworkService()

        let imageHolder = ImageHolder()
        let locationHolder = LocationHolder()

        return [
            AnyFlowStep(
                AuthorizeCameraStep(
                    onStopped: onCameraPermissionStopped,
                    onStoppedError: onCameraPermissionError,
                    autoOpenSettingsWhenStopped: autoOpenSettingsWhenPermissionStopped
                )
            ),
            AnyFlowStep(
                CaptureImageStep(
                    cameraService: cameraService,
                    onCaptured: { imageHolder.value = $0 }
                )
            ),
            AnyFlowStep(
                AuthorizeLocationStep(
                    onStopped: onLocationPermissionStopped,
                    onStoppedError: onLocationPermissionError,
                    autoOpenSettingsWhenStopped: autoOpenSettingsWhenPermissionStopped
                )
            ),
            AnyFlowStep(
                FetchLocationStep(
                    locationService: locationService,
                    onFetched: { locationHolder.value = $0 }
                )
            ),
            AnyFlowStep(
                UploadStep(
                    networkService: networkService,
                    imageProvider: { imageHolder.value },
                    locationProvider: { locationHolder.value },
                    onUploaded: onUploaded
                )
            )
        ]
    }

    /// 示例：已知只需要定位，不需要图片。
    static func locationOnlySteps(
        onLocationPermissionStopped: ((PermissionStopContext) -> Void)? = nil,
        onLocationPermissionError: ((FlowError.Permission) -> Void)? = nil,
        autoOpenSettingsWhenPermissionStopped: Bool = false,
        onUploaded: ((FlowUploadResponse) -> Void)? = nil
    ) -> [AnyFlowStep] {
        let locationService = CoreLocationService()
        let networkService = DemoFlowNetworkService()

        let locationHolder = LocationHolder()

        return [
            AnyFlowStep(
                AuthorizeLocationStep(
                    onStopped: onLocationPermissionStopped,
                    onStoppedError: onLocationPermissionError,
                    autoOpenSettingsWhenStopped: autoOpenSettingsWhenPermissionStopped
                )
            ),
            AnyFlowStep(
                FetchLocationStep(
                    locationService: locationService,
                    onFetched: { locationHolder.value = $0 }
                )
            ),
            AnyFlowStep(
                UploadStep(
                    networkService: networkService,
                    locationProvider: { locationHolder.value },
                    onUploaded: onUploaded
                )
            )
        ]
    }

    /// 示例：只做通知权限申请（不获取图片/定位）
    static func notificationOnlySteps(
        onNotificationPermissionStopped: ((PermissionStopContext) -> Void)? = nil,
        onNotificationPermissionError: ((FlowError.Permission) -> Void)? = nil,
        autoOpenSettingsWhenPermissionStopped: Bool = false,
        onUploaded: ((FlowUploadResponse) -> Void)? = nil
    ) -> [AnyFlowStep] {
        let networkService = DemoFlowNetworkService()
        return [
            AnyFlowStep(
                AuthorizeNotificationStep(
                    onStopped: onNotificationPermissionStopped,
                    onStoppedError: onNotificationPermissionError,
                    autoOpenSettingsWhenStopped: autoOpenSettingsWhenPermissionStopped
                )
            ),
            AnyFlowStep(UploadStep(networkService: networkService, onUploaded: onUploaded))
        ]
    }
}

private final class ImageHolder {
    var value: UIImage?
}

private final class LocationHolder {
    var value: CLLocation?
}

/*
 使用示例（例如在 ViewController 里）：

 let coordinator = FlowPipelineDemoFactory.makeCoordinator()
 coordinator.onStateChanged = { state in
     switch state {
     case .idle:
         print("flow idle")
     case .running(let stepID):
         print("running:", stepID)
     case .waitingAuthorization(let message):
         print("auth:", message)
     case .failed(let stepID, let error):
         print("failed:", stepID, error.localizedDescription)
     case .cancelled:
         print("cancelled")
     case .finished:
         print("finished")
     }
 }
 coordinator.onFinished = {
     print("flow done")
 }
 let steps = FlowPipelineDemoFactory.defaultSteps(
     onCameraPermissionStopped: { info in
         print("camera stopped:", info.reason, info.message, info.canOpenSettings)
     },
     onLocationPermissionStopped: { info in
         print("location stopped:", info.reason, info.message, info.canOpenSettings)
     },
     onUploaded: { response in
         print("requestID =", response.requestID)
     }
 )
 coordinator.start(steps: steps)
 */
