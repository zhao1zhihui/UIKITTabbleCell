//
//  Permission.swift
//  baseAndEx
//
//  Created by wb-zhaozhihui on 2026/3/6.
//

import UIKit
import AVFoundation
import CoreLocation
import UserNotifications

// MARK: - 权限结果枚举
enum PermissionResult {
    case success(SuccessType)      // 成功
    case failure(FailureType)      // 失败
    
    enum SuccessType {
        case authorized            // 已授权（之前就已经授权）
        case requested             // 申请授权成功（用户刚同意）
        
        var isAuthorized: Bool {
            return true
        }
    }
    
    enum FailureType: Error {
        case denied                // 已拒绝（之前就已经拒绝）
        case requestDenied         // 申请授权被拒绝（用户刚拒绝）
        case restricted            // 受限（家长控制）
        case systemError(Error?)   // 系统错误
        
        var localizedDescription: String {
            switch self {
            case .denied:
                return "用户已拒绝授权"
            case .requestDenied:
                return "用户拒绝授权申请"
            case .restricted:
                return "权限受限"
            case .systemError(let error):
                return "系统错误: \(error?.localizedDescription ?? "未知错误")"
            }
        }
    }
}

// MARK: - 授权前提示策略
enum PreRequestAlertStrategy {
    case none                        // 不弹窗，直接请求系统权限
    case system                       // 使用系统统一样式弹窗
    case custom((PermissionType, @escaping (Bool) -> Void) -> Void)  // 自定义弹窗，回调参数：是否继续
    
    static func custom(handler: @escaping (PermissionType, @escaping (Bool) -> Void) -> Void) -> PreRequestAlertStrategy {
        return .custom(handler)
    }
}

// MARK: - 拒绝/禁用后提示策略
enum PostDeniedAlertStrategy {
    case none                        // 不弹窗
    case system                       // 使用系统统一样式弹窗（引导去设置）
    case custom((PermissionType, @escaping () -> Void) -> Void)  // 自定义弹窗，回调参数：完成回调
    
    static func custom(handler: @escaping (PermissionType, @escaping () -> Void) -> Void) -> PostDeniedAlertStrategy {
        return .custom(handler)
    }
}

// MARK: - 位置请求配置
struct LocationRequestConfig {
    let shouldRequestLocation: Bool                    // 是否请求位置
    let waitForCompletion: Bool                        // 是否等待位置请求完成
    let handler: ((@escaping (Bool) -> Void) -> Void)? // 位置请求处理，回调参数：是否成功
    
    init(shouldRequestLocation: Bool = false,
         waitForCompletion: Bool = false,
         handler: ((@escaping (Bool) -> Void) -> Void)? = nil) {
        self.shouldRequestLocation = shouldRequestLocation
        self.waitForCompletion = waitForCompletion
        self.handler = handler
    }
    
    // 便捷方法：只需要发送位置，不等待
    static func sendLocation(handler: @escaping (@escaping (Bool) -> Void) -> Void) -> LocationRequestConfig {
        return LocationRequestConfig(shouldRequestLocation: true,
                                     waitForCompletion: false,
                                     handler: handler)
    }
    
    // 便捷方法：发送位置并等待完成
    static func sendLocationAndWait(handler: @escaping (@escaping (Bool) -> Void) -> Void) -> LocationRequestConfig {
        return LocationRequestConfig(shouldRequestLocation: true,
                                     waitForCompletion: true,
                                     handler: handler)
    }
}

// MARK: - 权限请求配置
struct PermissionRequestConfig {
    let preRequestStrategy: PreRequestAlertStrategy      // 授权前提示策略
    let postDeniedStrategy: PostDeniedAlertStrategy      // 拒绝/禁用后提示策略
    let locationConfig: LocationRequestConfig
    
    init(preRequestStrategy: PreRequestAlertStrategy = .system,
         postDeniedStrategy: PostDeniedAlertStrategy = .system,
         locationConfig: LocationRequestConfig = LocationRequestConfig()) {
        self.preRequestStrategy = preRequestStrategy
        self.postDeniedStrategy = postDeniedStrategy
        self.locationConfig = locationConfig
    }
    
    // 便捷初始化方法
    init(preRequestStrategy: PreRequestAlertStrategy = .system,
         postDeniedStrategy: PostDeniedAlertStrategy = .system,
         shouldRequestLocation: Bool = false,
         waitForLocationCompletion: Bool = false,
         locationHandler: ((@escaping (Bool) -> Void) -> Void)? = nil) {
        self.preRequestStrategy = preRequestStrategy
        self.postDeniedStrategy = postDeniedStrategy
        self.locationConfig = LocationRequestConfig(
            shouldRequestLocation: shouldRequestLocation,
            waitForCompletion: waitForLocationCompletion,
            handler: locationHandler
        )
    }
}

// MARK: - 权限协议
protocol Permission: AnyObject {  // 添加 AnyObject 确保只能被类遵循
    var type: PermissionType { get }
    var title: String { get }
    var purposeDescription: String { get }
    var config: PermissionRequestConfig { get set }
    
    func checkStatus(completion: @escaping (PermissionResult) -> Void)
    func requestSystem(completion: @escaping (PermissionResult) -> Void)
}

// MARK: - 权限类型
enum PermissionType: String {
    case camera, location, notification
    
    var displayName: String {
        switch self {
        case .camera: return "相机"
        case .location: return "位置"
        case .notification: return "通知"
        }
    }
}

// MARK: - 相机权限
class CameraPermission: Permission {
    let type: PermissionType = .camera
    let title = "相机权限"
    let purposeDescription = "拍照和录制视频"
    var config: PermissionRequestConfig
    
    init(config: PermissionRequestConfig = PermissionRequestConfig()) {
        self.config = config
    }
    
    func checkStatus(completion: @escaping (PermissionResult) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        handleStatusBasedOn(status: status, completion: completion)
    }
    
    func requestSystem(completion: @escaping (PermissionResult) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    completion(.success(.requested))
                } else {
                    completion(.failure(.requestDenied))
                }
            }
        }
    }
    
    private func handleStatusBasedOn(status: AVAuthorizationStatus, completion: @escaping (PermissionResult) -> Void) {
        switch status {
        case .authorized:
            print("✅ 相机已授权")
            DispatchQueue.main.async {
                completion(.success(.authorized))
            }
            
        case .notDetermined:
            print("⚠️ 相机未决定")
            handleNotDetermined(completion: completion)
            
        case .denied:
            print("❌ 相机已拒绝")
            handleDenied(completion: completion)
            
        case .restricted:
            print("❌ 相机受限")
            handleRestricted(completion: completion)
            
        @unknown default:
            completion(.failure(.systemError(nil)))
        }
    }
    
    private func handleNotDetermined(completion: @escaping (PermissionResult) -> Void) {
        switch config.preRequestStrategy {
        case .none:
            // 不弹窗，直接请求系统权限
            requestSystem(completion: completion)
            
        case .system:
            // 显示系统统一弹窗
            showSystemPreRequestAlert { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: completion)
                } else {
                    completion(.failure(.requestDenied))
                }
            }
            
        case .custom(let handler):
            // 使用自定义弹窗
            handler(self.type) { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: completion)
                } else {
                    completion(.failure(.requestDenied))
                }
            }
        }
    }
    
    private func handleDenied(completion: @escaping (PermissionResult) -> Void) {
        switch config.postDeniedStrategy {
        case .none:
            completion(.failure(.denied))
            
        case .system:
            showSystemSettingsAlert { [weak self] in
                completion(.failure(.denied))
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] in
                completion(.failure(.denied))
            }
        }
    }
    
    private func handleRestricted(completion: @escaping (PermissionResult) -> Void) {
        switch config.postDeniedStrategy {
        case .none:
            completion(.failure(.restricted))
            
        case .system:
            showSystemRestrictedAlert { [weak self] in
                completion(.failure(.restricted))
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] in
                completion(.failure(.restricted))
            }
        }
    }
    
    private func showSystemPreRequestAlert(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion(false)
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "我们需要\(self.title)来\(self.purposeDescription)，是否允许？",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "不允许", style: .cancel) { _ in
                completion(false)
            })
            
            alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                completion(true)
            })
            
            topVC.present(alert, animated: true)
        }
    }
    
    private func showSystemSettingsAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "您已拒绝\(self.title)，需要前往设置开启才能使用\(self.purposeDescription)功能",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                completion()
            })
            
            alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                completion()
            })
            
            topVC.present(alert, animated: true)
        }
    }
    
    private func showSystemRestrictedAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "\(self.title)受限",
                message: "您的\(self.title)受到限制，无法使用相关功能。请联系管理员或检查家长控制设置。",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                completion()
            })
            
            topVC.present(alert, animated: true)
        }
    }
}

// MARK: - 位置权限
class LocationPermission: NSObject, Permission {
    let type: PermissionType = .location
    let title = "位置权限"
    let purposeDescription = "获取您的位置信息"
    var config: PermissionRequestConfig
    
    private var locationManager: CLLocationManager
    private var requestCompletion: ((PermissionResult) -> Void)?
    private var permissionCompletion: ((PermissionResult) -> Void)?
    private var isRequestingLocation = false
    
    init(config: PermissionRequestConfig = PermissionRequestConfig()) {
        self.config = config
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }
    
    func checkStatus(completion: @escaping (PermissionResult) -> Void) {
        self.permissionCompletion = completion
        let status = locationManager.authorizationStatus
        handleStatusBasedOn(status: status)
    }
    
    func requestSystem(completion: @escaping (PermissionResult) -> Void) {
        requestCompletion = completion
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func handleStatusBasedOn(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("✅ 位置已授权")
            handleAuthorized()
            
        case .notDetermined:
            print("⚠️ 位置未决定")
            handleNotDetermined()
            
        case .denied:
            print("❌ 位置已拒绝")
            handleDenied()
            
        case .restricted:
            print("❌ 位置受限")
            handleRestricted()
            
        @unknown default:
            permissionCompletion?(.failure(.systemError(nil)))
            permissionCompletion = nil
        }
    }
    
    private func handleAuthorized() {
        // 如果配置了需要获取位置
        if config.locationConfig.shouldRequestLocation {
            if let handler = config.locationConfig.handler {
                // 有自定义handler，调用它
                handler { [weak self] success in
                    guard let self = self else { return }
                    
                    if self.config.locationConfig.waitForCompletion {
                        // 需要等待位置请求完成
                        self.permissionCompletion?(.success(.authorized))
                    } else {
                        // 不需要等待，直接返回成功
                        self.permissionCompletion?(.success(.authorized))
                    }
                    self.permissionCompletion = nil
                }
            } else {
                // 没有自定义handler，使用默认的定位
                isRequestingLocation = true
                requestCurrentLocation()
                
                if !config.locationConfig.waitForCompletion {
                    permissionCompletion?(.success(.authorized))
                    permissionCompletion = nil
                }
            }
        } else {
            // 不需要获取位置，直接返回
            permissionCompletion?(.success(.authorized))
            permissionCompletion = nil
        }
    }
    
    private func handleNotDetermined() {
        switch config.preRequestStrategy {
        case .none:
            requestSystem(completion: { [weak self] result in
                self?.handleSystemRequestResult(result)
            })
            
        case .system:
            showSystemPreRequestAlert { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: { result in
                        self.handleSystemRequestResult(result)
                    })
                } else {
                    self.permissionCompletion?(.failure(.requestDenied))
                    self.permissionCompletion = nil
                }
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: { result in
                        self.handleSystemRequestResult(result)
                    })
                } else {
                    self.permissionCompletion?(.failure(.requestDenied))
                    self.permissionCompletion = nil
                }
            }
        }
    }
    
    private func handleDenied() {
        switch config.postDeniedStrategy {
        case .none:
            permissionCompletion?(.failure(.denied))
            permissionCompletion = nil
            
        case .system:
            showSystemSettingsAlert { [weak self] in
                self?.permissionCompletion?(.failure(.denied))
                self?.permissionCompletion = nil
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] in
                self?.permissionCompletion?(.failure(.denied))
                self?.permissionCompletion = nil
            }
        }
    }
    
    private func handleRestricted() {
        switch config.postDeniedStrategy {
        case .none:
            permissionCompletion?(.failure(.restricted))
            permissionCompletion = nil
            
        case .system:
            showSystemRestrictedAlert { [weak self] in
                self?.permissionCompletion?(.failure(.restricted))
                self?.permissionCompletion = nil
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] in
                self?.permissionCompletion?(.failure(.restricted))
                self?.permissionCompletion = nil
            }
        }
    }
    
    private func handleSystemRequestResult(_ result: PermissionResult) {
        switch result {
        case .success(let type):
            switch type {
            case .requested:
                // 用户刚同意，需要检查是否需要获取位置
                if config.locationConfig.shouldRequestLocation {
                    if let handler = config.locationConfig.handler {
                        handler { [weak self] success in
                            if self?.config.locationConfig.waitForCompletion == true {
                                self?.permissionCompletion?(.success(.requested))
                            } else {
                                self?.permissionCompletion?(.success(.requested))
                            }
                            self?.permissionCompletion = nil
                        }
                    } else {
                        isRequestingLocation = true
                        requestCurrentLocation()
                        
                        if !config.locationConfig.waitForCompletion {
                            permissionCompletion?(.success(.requested))
                            permissionCompletion = nil
                        }
                    }
                } else {
                    permissionCompletion?(.success(.requested))
                    permissionCompletion = nil
                }
                
            case .authorized:
                permissionCompletion?(.success(.requested))
                permissionCompletion = nil
            }
            
        case .failure(let error):
            permissionCompletion?(.failure(error))
            permissionCompletion = nil
        }
    }
    
    private func requestCurrentLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - UI Alerts
    private func showSystemPreRequestAlert(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion(false)
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "我们需要\(self.title)来\(self.purposeDescription)，是否允许？",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "不允许", style: .cancel) { _ in
                completion(false)
            })
            
            alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                completion(true)
            })
            
            topVC.present(alert, animated: true)
        }
    }
    
    private func showSystemSettingsAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "您已拒绝\(self.title)，需要前往设置开启才能使用\(self.purposeDescription)功能",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                completion()
            })
            
            alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                completion()
            })
            
            topVC.present(alert, animated: true)
        }
    }
    
    private func showSystemRestrictedAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "\(self.title)受限",
                message: "您的\(self.title)受到限制，无法使用相关功能。请联系管理员或检查家长控制设置。",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                completion()
            })
            
            topVC.present(alert, animated: true)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationPermission: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if let requestCompletion = requestCompletion {
            DispatchQueue.main.async { [weak self] in
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    requestCompletion(.success(.requested))
                case .denied:
                    requestCompletion(.failure(.requestDenied))
                case .restricted:
                    requestCompletion(.failure(.restricted))
                default:
                    requestCompletion(.failure(.systemError(nil)))
                }
                self?.requestCompletion = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRequestingLocation else { return }
        
        isRequestingLocation = false
        manager.stopUpdatingLocation()
        
        DispatchQueue.main.async { [weak self] in
            if let completion = self?.permissionCompletion {
                completion(.success(.authorized))
                self?.permissionCompletion = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isRequestingLocation else { return }
        
        print("❌ 位置获取失败: \(error.localizedDescription)")
        isRequestingLocation = false
        manager.stopUpdatingLocation()
        
        DispatchQueue.main.async { [weak self] in
            if let completion = self?.permissionCompletion {
                // 位置获取失败，但权限已经授权，所以还是返回成功
                completion(.success(.authorized))
                self?.permissionCompletion = nil
            }
        }
    }
}

// MARK: - 通知权限
class NotificationPermission: Permission {
    let type: PermissionType = .notification
    let title = "通知权限"
    let purposeDescription = "发送重要通知"
    var config: PermissionRequestConfig
    
    init(config: PermissionRequestConfig = PermissionRequestConfig()) {
        self.config = config
    }
    
    func checkStatus(completion: @escaping (PermissionResult) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.handleStatusBasedOn(status: settings.authorizationStatus, completion: completion)
            }
        }
    }
    
    func requestSystem(completion: @escaping (PermissionResult) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.systemError(error)))
                } else if granted {
                    completion(.success(.requested))
                } else {
                    completion(.failure(.requestDenied))
                }
            }
        }
    }
    
    private func handleStatusBasedOn(status: UNAuthorizationStatus, completion: @escaping (PermissionResult) -> Void) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            print("✅ 通知已授权")
            completion(.success(.authorized))
            
        case .notDetermined:
            print("⚠️ 通知未决定")
            handleNotDetermined(completion: completion)
            
        case .denied:
            print("❌ 通知已拒绝")
            handleDenied(completion: completion)
            
        @unknown default:
            completion(.failure(.systemError(nil)))
        }
    }
    
    private func handleNotDetermined(completion: @escaping (PermissionResult) -> Void) {
        switch config.preRequestStrategy {
        case .none:
            requestSystem(completion: completion)
            
        case .system:
            showSystemPreRequestAlert { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: completion)
                } else {
                    completion(.failure(.requestDenied))
                }
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] shouldContinue in
                guard let self = self else { return }
                if shouldContinue {
                    self.requestSystem(completion: completion)
                } else {
                    completion(.failure(.requestDenied))
                }
            }
        }
    }
    
    private func handleDenied(completion: @escaping (PermissionResult) -> Void) {
        switch config.postDeniedStrategy {
        case .none:
            completion(.failure(.denied))
            
        case .system:
            showSystemSettingsAlert { [weak self] in
                completion(.failure(.denied))
            }
            
        case .custom(let handler):
            handler(self.type) { [weak self] in
                completion(.failure(.denied))
            }
        }
    }
    
    private func showSystemPreRequestAlert(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion(false)
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "我们需要\(self.title)来\(self.purposeDescription)，是否允许？",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "不允许", style: .cancel) { _ in
                completion(false)
            })
            
            alert.addAction(UIAlertAction(title: "允许", style: .default) { _ in
                completion(true)
            })
            
            topVC.present(alert, animated: true)
        }
    }
    
    private func showSystemSettingsAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let topVC = UIApplication.shared.topViewController() else {
                print("❌ 没有找到可用的ViewController来显示弹窗")
                completion()
                return
            }
            
            let alert = UIAlertController(
                title: "需要\(self.title)",
                message: "您已拒绝\(self.title)，需要前往设置开启才能使用\(self.purposeDescription)功能",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                completion()
            })
            
            alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                completion()
            })
            
            topVC.present(alert, animated: true)
        }
    }
}

// MARK: - 权限队列管理器
class PermissionQueueManager {
    static let shared = PermissionQueueManager()
    
    private var queue: [(permission: any Permission, completion: ((PermissionResult) -> Void)?)] = []
    private var isProcessing = false
    private var finalCompletion: (() -> Void)?
    
    // 强引用当前正在处理的权限
    private var currentPermission: (any Permission)?
    
    private init() {}
    
    func request(_ permissions: [any Permission],
                 completion: (() -> Void)? = nil) {
        self.finalCompletion = completion
        
        for permission in permissions {
            queue.append((permission, nil))
        }
        
        if !isProcessing {
            processNext()
        }
    }
    
    func request(_ permissions: [(permission: any Permission, completion: ((PermissionResult) -> Void)?)],
                 completion: (() -> Void)? = nil) {
        self.finalCompletion = completion
        queue.append(contentsOf: permissions)
        
        if !isProcessing {
            processNext()
        }
    }
    
    private func processNext() {
        guard !queue.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.finalCompletion?()
                self?.isProcessing = false
                self?.currentPermission = nil
            }
            return
        }
        
        isProcessing = true
        let item = queue.removeFirst()
        
        // 强持有当前权限
        currentPermission = item.permission
        
        DispatchQueue.main.async { [weak self] in
            item.permission.checkStatus { [weak self] result in
                guard let self = self else { return }
                
                // 调用单个权限的completion
                item.completion?(result)
                
                // 当前权限处理完成，释放强引用
                self.currentPermission = nil
                
                // 处理下一个权限
                self.processNext()
            }
        }
    }
    
    func clear() {
        queue.removeAll()
        isProcessing = false
        currentPermission = nil
    }
    
    func skipCurrent() {
        guard isProcessing else { return }
        currentPermission = nil
        processNext()
    }
}

// MARK: - UIApplication扩展
extension UIApplication {
    func topViewController() -> UIViewController? {
        // 获取所有连接的场景
        let scenes = connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        
        // 获取第一个活跃场景的窗口
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                var topController = window.rootViewController
                
                while let presentedController = topController?.presentedViewController {
                    topController = presentedController
                }
                
                return topController
            }
        }
        
        // 如果没有找到活跃场景，尝试获取任何场景
        for scene in connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                var topController = window.rootViewController
                
                while let presentedController = topController?.presentedViewController {
                    topController = presentedController
                }
                
                return topController
            }
        }
        
        print("❌ 没有找到可用的ViewController")
        return nil
    }
}
