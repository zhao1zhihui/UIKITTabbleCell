import Foundation

// MARK: - 状态与错误

/// 流水线状态（关联值 enum，便于 switch 穷尽处理）
enum FlowState {
    case idle
    case running(stepID: String)
    case waitingAuthorization(message: String)
    case failed(stepID: String, error: FlowError)
    case cancelled
    case finished
}

/// Step 之间的能力依赖标识：
/// - requires：当前 Step 开始执行前，必须已具备的能力
/// - provides：当前 Step 成功后，向后续 Step 提供的能力
enum FlowCapability: Hashable, CustomStringConvertible {
    case cameraAuthorized
    case locationAuthorized
    case notificationAuthorized
    case cameraImageCaptured
    case locationFetched
    case custom(String)

    var description: String {
        switch self {
        case .cameraAuthorized:
            return "cameraAuthorized"
        case .locationAuthorized:
            return "locationAuthorized"
        case .notificationAuthorized:
            return "notificationAuthorized"
        case .cameraImageCaptured:
            return "cameraImageCaptured"
        case .locationFetched:
            return "locationFetched"
        case .custom(let value):
            return value
        }
    }
}

/// 流水线统一错误类型（顶层统一 + 内部定制）
enum FlowError: LocalizedError {
    case permission(Permission)
    case camera(Camera)
    case location(Location)
    case network(Network)
    case pipeline(Pipeline)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .permission(let error):
            return error.errorDescription
        case .camera(let error):
            return error.errorDescription
        case .location(let error):
            return error.errorDescription
        case .network(let error):
            return error.errorDescription
        case .pipeline(let error):
            return error.errorDescription
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> FlowError {
        if let flowError = error as? FlowError {
            return flowError
        }
        if let permissionError = error as? Permission {
            return .permission(permissionError)
        }
        if let cameraError = error as? Camera {
            return .camera(cameraError)
        }
        if let locationError = error as? Location {
            return .location(locationError)
        }
        if let networkError = error as? Network {
            return .network(networkError)
        }
        if let pipelineError = error as? Pipeline {
            return .pipeline(pipelineError)
        }
        return .unknown(message: error.localizedDescription)
    }

    enum Permission: LocalizedError {
        case servicesDisabled(feature: PermissionFeature, message: String)
        case denied(feature: PermissionFeature, message: String)
        case requestFailed(feature: PermissionFeature, message: String)
        case restricted(feature: PermissionFeature, message: String)
        case unavailable(feature: PermissionFeature, message: String)

        var errorDescription: String? {
            switch self {
            case .servicesDisabled(_, let message):
                return message
            case .denied(_, let message):
                return message
            case .requestFailed(_, let message):
                return message
            case .restricted(_, let message):
                return message
            case .unavailable(_, let message):
                return message
            }
        }
    }

    enum Camera: LocalizedError {
        case captureFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .captureFailed(let message):
                return message
            }
        }
    }

    enum Location: LocalizedError {
        case fetchFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return message
            }
        }
    }

    enum Network: LocalizedError {
        case requestFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .requestFailed(let message):
                return message
            }
        }
    }

    enum Pipeline: LocalizedError {
        case invalidPipeline
        case invalidJumpTarget(target: String)
        case missingDependencies(stepID: String, dependencies: [FlowCapability])

        var errorDescription: String? {
            switch self {
            case .invalidPipeline:
                return "流水线为空，无法启动"
            case .invalidJumpTarget(let target):
                return "无效的跳转目标：\(target)"
            case .missingDependencies(let stepID, let dependencies):
                let names = dependencies.map(\.description).joined(separator: ", ")
                return "步骤[\(stepID)]缺少依赖：\(names)"
            }
        }
    }
}

// MARK: - Step 协议与结果

/// Step 的执行结果：
/// - next：继续执行队列中的下一步
/// - insert：把新步骤插入到当前队列头部（可随时介入）
/// - jump：跳转到某个 stepID
/// - finish：提前结束流水线
enum FlowDirective {
    case next
    case insert([AnyFlowStep])
    case jump(to: String)
    case finish
}

/// Step 执行前的依赖上下文（统一依赖处理入口）。
struct FlowDependencyContext {
    let stepID: String
    let requires: Set<FlowCapability>
    let provides: Set<FlowCapability>
    let resolvedCapabilities: Set<FlowCapability>

    var missingDependencies: Set<FlowCapability> {
        requires.subtracting(resolvedCapabilities)
    }
}

/// Step 执行前决策：
/// - run：执行当前 step
/// - skip：跳过当前 step，继续下一个
/// - finish：提前结束整个流程
/// - fail：以错误结束流程
enum FlowDependencyDecision {
    case run
    case skip(reason: String?)
    case finish(reason: String?)
    case fail(FlowError)
}

/// 单个步骤协议。每个具体能力都实现为一个 Step。
protocol FlowStep {
    var id: String { get }
    var requires: Set<FlowCapability> { get }
    var provides: Set<FlowCapability> { get }
    func dependencyDecision(context: FlowDependencyContext) -> FlowDependencyDecision
    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective
}

extension FlowStep {
    var requires: Set<FlowCapability> { [] }
    var provides: Set<FlowCapability> { [] }

    /// 默认依赖策略：缺依赖即失败。
    /// 具体 Step 可覆盖，改成 skip/finish 或更复杂条件。
    func dependencyDecision(context: FlowDependencyContext) -> FlowDependencyDecision {
        let missing = context.missingDependencies
        guard missing.isEmpty else {
            let sortedMissing = Array(missing).sorted { $0.description < $1.description }
            return .fail(
                .pipeline(
                    .missingDependencies(stepID: context.stepID, dependencies: sortedMissing)
                )
            )
        }
        return .run
    }
}

/// 类型擦除，保证不同 Step 可以放到同一个数组里统一编排。
struct AnyFlowStep: FlowStep {
    let id: String
    let requires: Set<FlowCapability>
    let provides: Set<FlowCapability>
    private let dependencyDecisionBlock: (FlowDependencyContext) -> FlowDependencyDecision
    private let runBlock: (@escaping @MainActor (FlowState) -> Void) async throws -> FlowDirective

    init<S: FlowStep>(_ step: S) {
        self.id = step.id
        self.requires = step.requires
        self.provides = step.provides
        self.dependencyDecisionBlock = { context in
            step.dependencyDecision(context: context)
        }
        self.runBlock = { emitState in
            try await step.run(emitState: emitState)
        }
    }

    func dependencyDecision(context: FlowDependencyContext) -> FlowDependencyDecision {
        dependencyDecisionBlock(context)
    }

    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective {
        try await runBlock(emitState)
    }
}

// MARK: - Interceptor（横切能力）

/// 横切能力协议：
/// 典型用途：日志、埋点、耗时统计、统一错误上报。
protocol FlowInterceptor {
    func beforeStep(stepID: String) async
    func afterStep(stepID: String, directive: FlowDirective) async
    func onStepSkipped(stepID: String, reason: String?) async
    func onStepError(stepID: String, error: FlowError) async
}

extension FlowInterceptor {
    func beforeStep(stepID: String) async {}
    func afterStep(stepID: String, directive: FlowDirective) async {}
    func onStepSkipped(stepID: String, reason: String?) async {}
    func onStepError(stepID: String, error: FlowError) async {}
}

/// 默认日志拦截器（示例）
struct FlowLogInterceptor: FlowInterceptor {
    func beforeStep(stepID: String) async {
        #if DEBUG
        print("before step: \(stepID)")
        #endif
    }

    func afterStep(stepID: String, directive: FlowDirective) async {
        #if DEBUG
        print("after step: \(stepID), directive: \(directive)")
        #endif
    }

    func onStepSkipped(stepID: String, reason: String?) async {
        #if DEBUG
        if let reason {
            print("skip step: \(stepID), reason: \(reason)")
        } else {
            print("skip step: \(stepID)")
        }
        #endif
    }

    func onStepError(stepID: String, error: FlowError) async {
        #if DEBUG
        print("step error: \(stepID), error: \(error)")
        #endif
    }
}

// MARK: - Coordinator（编排器）

/// 核心编排器：
/// - 负责队列执行
/// - 负责状态管理
/// - 负责 insert/jump/finish 等流程控制
@MainActor
final class FlowCoordinator {
    private let interceptors: [FlowInterceptor]
    private var runningTask: Task<Void, Never>?

    private(set) var state: FlowState = .idle {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((FlowState) -> Void)?
    var onFinished: (() -> Void)?

    init(interceptors: [FlowInterceptor] = []) {
        self.interceptors = interceptors
    }

    func start(steps: [AnyFlowStep]) {
        runningTask?.cancel()
        runningTask = nil

        runningTask = Task { [weak self] in
            await self?.run(steps: steps)
        }
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
        state = .cancelled
    }

    private func run(steps: [AnyFlowStep]) async {
        guard !steps.isEmpty else {
            state = .failed(stepID: "pipeline", error: .pipeline(.invalidPipeline))
            return
        }

        var queue = steps
        var stepBook = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
        var resolvedCapabilities = Set<FlowCapability>()

        do {
            while !queue.isEmpty {
                try Task.checkCancellation()

                let step = queue.removeFirst()

                let dependencyContext = FlowDependencyContext(
                    stepID: step.id,
                    requires: step.requires,
                    provides: step.provides,
                    resolvedCapabilities: resolvedCapabilities
                )

                switch step.dependencyDecision(context: dependencyContext) {
                case .run:
                    break
                case .skip(let reason):
                    for interceptor in interceptors {
                        await interceptor.onStepSkipped(stepID: step.id, reason: reason)
                    }
                    continue
                case .finish:
                    state = .finished
                    onFinished?()
                    return
                case .fail(let error):
                    for interceptor in interceptors {
                        await interceptor.onStepError(stepID: step.id, error: error)
                    }
                    state = .failed(stepID: step.id, error: error)
                    return
                }

                state = .running(stepID: step.id)

                for interceptor in interceptors {
                    await interceptor.beforeStep(stepID: step.id)
                }

                do {
                    let directive = try await step.run(
                        emitState: { [weak self] nextState in
                            self?.state = nextState
                        }
                    )

                    for interceptor in interceptors {
                        await interceptor.afterStep(stepID: step.id, directive: directive)
                    }

                    switch directive {
                    case .next:
                        resolvedCapabilities.formUnion(step.provides)
                        continue
                    case .finish:
                        state = .finished
                        onFinished?()
                        return
                    case .insert(let newSteps):
                        resolvedCapabilities.formUnion(step.provides)
                        for newStep in newSteps {
                            stepBook[newStep.id] = newStep
                        }
                        queue.insert(contentsOf: newSteps, at: 0)
                    case .jump(let targetID):
                        resolvedCapabilities.formUnion(step.provides)
                        if let index = queue.firstIndex(where: { $0.id == targetID }) {
                            queue = Array(queue[index...])
                        } else if let fallbackStep = stepBook[targetID] {
                            queue.insert(fallbackStep, at: 0)
                        } else {
                            throw FlowError.pipeline(.invalidJumpTarget(target: targetID))
                        }
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let flowError = FlowError.from(error)
                    for interceptor in interceptors {
                        await interceptor.onStepError(stepID: step.id, error: flowError)
                    }
                    state = .failed(stepID: step.id, error: flowError)
                    return
                }
            }

            state = .finished
            onFinished?()
        } catch {
            state = .cancelled
        }
    }
}
