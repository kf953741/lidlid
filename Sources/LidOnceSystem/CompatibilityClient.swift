import Foundation
import LidLidServiceProtocol

public struct CompatibilityStatus {
    public let active: Bool
    public let recoveryPending: Bool
}

/// Main-queue client; every call has a deadline. The service authenticates the
/// client signature and the client independently pins the daemon's signature.
public final class CompatibilityClient {
    private var connection: NSXPCConnection?
    public init() {}
    deinit { connection?.invalidate() }
    public func invalidate() {
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate(); connection = nil
    }
    public func status(_ reply: @escaping (Result<CompatibilityStatus, Error>) -> Void) {
        call(reply) { proxy, finish in
            proxy.status { version, active, pending in
                guard version == CompatibilityService.version else {
                    finish(.failure(PowerError(text: "请更新盖盖兼容组件"))); return
                }
                finish(.success(CompatibilityStatus(active: active, recoveryPending: pending)))
            }
        }
    }
    public func begin(minutes: Int, _ reply: @escaping (Result<Void, Error>) -> Void) {
        command(reply) { $0.beginSession(minutes: minutes, reply: $1) }
    }
    public func renew(_ reply: @escaping (Result<Void, Error>) -> Void) {
        command(reply) { $0.renewSession(reply: $1) }
    }
    public func end(_ reply: @escaping (Result<Void, Error>) -> Void) {
        command(reply) { $0.endSession(reply: $1) }
    }
    public func prepareForRemoval(_ reply: @escaping (Result<Void, Error>) -> Void) {
        command(reply) { $0.prepareForRemoval(reply: $1) }
    }
    private func command(_ reply: @escaping (Result<Void, Error>) -> Void,
                         operation: @escaping (LidLidSleepServiceProtocol, @escaping (Bool, String?) -> Void) -> Void) {
        call(reply) { proxy, finish in
            operation(proxy) { success, message in
                if success { finish(.success(())) }
                else { finish(.failure(PowerError(text: message ?? "兼容组件暂时不可用，请重新打开组件检查"))) }
            }
        }
    }
    private func call<Value>(_ reply: @escaping (Result<Value, Error>) -> Void,
                             operation: (LidLidSleepServiceProtocol, @escaping (Result<Value, Error>) -> Void) -> Void) {
        if connection == nil {
            let channel = NSXPCConnection(machServiceName: CompatibilityService.name, options: .privileged)
            channel.remoteObjectInterface = NSXPCInterface(with: LidLidSleepServiceProtocol.self)
            channel.setCodeSigningRequirement(CompatibilityService.daemonRequirement)
            channel.resume(); connection = channel
        }
        let current = connection!
        let gate = ReplyGate<Value> { [weak self] result in
            DispatchQueue.main.async {
                if case .failure = result, self?.connection === current { self?.invalidate() }
                reply(result)
            }
        }
        let unavailable = PowerError(text: "请先安装并授权盖盖兼容组件")
        guard let proxy = current.remoteObjectProxyWithErrorHandler({ _ in gate.finish(.failure(unavailable)) }) as? LidLidSleepServiceProtocol else {
            gate.finish(.failure(unavailable)); return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
            gate.finish(.failure(PowerError(text: "兼容组件响应超时，请保持开盖并检查组件")))
        }
        operation(proxy) { gate.finish($0) }
    }
}

private final class ReplyGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: ((Result<Value, Error>) -> Void)?
    init(_ callback: @escaping (Result<Value, Error>) -> Void) { self.callback = callback }
    func finish(_ result: Result<Value, Error>) {
        lock.lock(); let callback = self.callback; self.callback = nil; lock.unlock()
        callback?(result)
    }
}
