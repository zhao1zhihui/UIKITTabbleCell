import Foundation
import UIKit
import CoreLocation

// MARK: - 能力步骤（获取图片 / 定位）

/// 拍照步骤：依赖相机服务，通过回调把图片交给业务侧。
struct CaptureImageStep: FlowStep {
    let id: String
    let cameraService: CameraService
    let mode: CameraMode
    let onCaptured: (UIImage) -> Void

    init(
        id: String = "camera.capture",
        cameraService: CameraService,
        mode: CameraMode = .system,
        onCaptured: @escaping (UIImage) -> Void
    ) {
        self.id = id
        self.cameraService = cameraService
        self.mode = mode
        self.onCaptured = onCaptured
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        _ = emitState
        do {
            let image = try await cameraService.openCamera(mode: mode)
            onCaptured(image)
            return .next
        } catch {
            throw FlowError.cameraCaptureFailed(message: "获取图片失败：\(error.localizedDescription)")
        }
    }
}

/// 定位步骤：依赖定位服务，通过回调把定位交给业务侧。
struct FetchLocationStep: FlowStep {
    let id: String
    let locationService: LocationService
    let onFetched: (CLLocation) -> Void

    init(
        id: String = "location.fetch",
        locationService: LocationService,
        onFetched: @escaping (CLLocation) -> Void
    ) {
        self.id = id
        self.locationService = locationService
        self.onFetched = onFetched
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        _ = emitState
        do {
            let location = try await locationService.requestOneShotLocation()
            onFetched(location)
            return .next
        } catch {
            throw FlowError.locationFailed(message: "获取定位失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 网络步骤

/// 上传步骤：通过 provider 获取当前已准备好的数据，不依赖全局 context。
struct UploadStep: FlowStep {
    let id: String
    let networkService: FlowNetworkService
    let imageProvider: () -> UIImage?
    let locationProvider: () -> CLLocation?
    let onUploaded: ((FlowUploadResponse) -> Void)?

    init(
        id: String = "network.upload",
        networkService: FlowNetworkService,
        imageProvider: @escaping () -> UIImage? = { nil },
        locationProvider: @escaping () -> CLLocation? = { nil },
        onUploaded: ((FlowUploadResponse) -> Void)? = nil
    ) {
        self.id = id
        self.networkService = networkService
        self.imageProvider = imageProvider
        self.locationProvider = locationProvider
        self.onUploaded = onUploaded
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        _ = emitState
        do {
            let response = try await networkService.upload(
                image: imageProvider(),
                location: locationProvider()
            )
            onUploaded?(response)
            return .next
        } catch {
            throw FlowError.networkFailed(message: "网络请求失败：\(error.localizedDescription)")
        }
    }
}
