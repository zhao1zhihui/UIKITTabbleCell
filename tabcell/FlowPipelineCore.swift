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

/// 流水线统一错误类型（所有 Step 都建议抛这个）
enum FlowError: LocalizedError {
    case authorizationDenied(message: String)
    case authorizationRequestFailed(message: String)
    case cameraCaptureFailed(message: String)
    case locationFailed(message: String)
    case networkFailed(message: String)
    case invalidPipeline
    case invalidJumpTarget(target: String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            return message
        case .authorizationRequestFailed(let message):
            return message
        case .cameraCaptureFailed(let message):
            return message
        case .locationFailed(let message):
            return message
        case .networkFailed(let message):
            return message
        case .invalidPipeline:
            return "流水线为空，无法启动"
        case .invalidJumpTarget(let target):
            return "无效的跳转目标：\(target)"
        case .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> FlowError {
        if let flowError = error as? FlowError {
            return flowError
        }
        return .unknown(message: error.localizedDescription)
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

/// 单个步骤协议。每个具体能力都实现为一个 Step。
protocol FlowStep {
    var id: String { get }
    func run(
        emitState: @escaping @MainActor (FlowState) -> Void
    ) async throws -> FlowDirective
}

/// 类型擦除，保证不同 Step 可以放到同一个数组里统一编排。
struct AnyFlowStep: FlowStep {
    let id: String
    private let runBlock: (@escaping @MainActor (FlowState) -> Void) async throws -> FlowDirective

    init<S: FlowStep>(_ step: S) {
        self.id = step.id
        self.runBlock = { emitState in
            try await step.run(emitState: emitState)
        }
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
    func onStepError(stepID: String, error: FlowError) async
}

extension FlowInterceptor {
    func beforeStep(stepID: String) async {}
    func afterStep(stepID: String, directive: FlowDirective) async {}
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
            state = .failed(stepID: "pipeline", error: .invalidPipeline)
            return
        }

        var queue = steps
        var stepBook = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })

        do {
            while !queue.isEmpty {
                try Task.checkCancellation()

                let step = queue.removeFirst()
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
                        continue
                    case .finish:
                        state = .finished
                        onFinished?()
                        return
                    case .insert(let newSteps):
                        for newStep in newSteps {
                            stepBook[newStep.id] = newStep
                        }
                        queue.insert(contentsOf: newSteps, at: 0)
                    case .jump(let targetID):
                        if let index = queue.firstIndex(where: { $0.id == targetID }) {
                            queue = Array(queue[index...])
                        } else if let fallbackStep = stepBook[targetID] {
                            queue.insert(fallbackStep, at: 0)
                        } else {
                            throw FlowError.invalidJumpTarget(target: targetID)
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
