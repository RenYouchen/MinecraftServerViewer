//
//  MinecraftConnection.swift
//  MinecraftServerViewer
//
//  Async wrapper around NWConnection used by both status protocols.
//

import Foundation
import Network

/// A single TCP or UDP connection with buffered async reads.
///
/// Reads and writes must come from one task at a time (the `run` body);
/// only `cancel()` may be called concurrently.
nonisolated final class MinecraftConnection: @unchecked Sendable {
    enum Transport {
        case tcp, udp
    }

    private let connection: NWConnection
    private let transport: Transport
    private let queue = DispatchQueue(label: "MinecraftServerViewer.MinecraftConnection")
    private var buffer = Data()

    init(host: String, port: Int, transport: Transport) throws {
        guard !host.isEmpty, let nwPort = UInt16(exactly: port).flatMap(NWEndpoint.Port.init(rawValue:)), port > 0 else {
            throw ServerStatusError.invalidURL
        }
        self.transport = transport
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: transport == .tcp ? .tcp : .udp
        )
    }

    /// Connects, runs `body`, and always closes the connection afterwards.
    /// Throws `ServerStatusError.timeout` if the whole exchange exceeds `timeout`.
    func run<T: Sendable>(
        timeout: Duration,
        _ body: @escaping @Sendable (MinecraftConnection) async throws -> T
    ) async throws -> T {
        defer { cancel() }
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    try await self.start()
                    return try await body(self)
                } onCancel: {
                    self.cancel()
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ServerStatusError.timeout
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
    }

    func cancel() {
        connection.cancel()
    }

    // MARK: - Lifecycle

    private func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [connection] state in
                let outcome: Error?
                switch state {
                case .ready: outcome = nil
                case .waiting(let error), .failed(let error): outcome = Self.mapError(error)
                case .cancelled: outcome = CancellationError()
                default: return
                }
                // Resume exactly once; later state changes surface through reads instead.
                connection.stateUpdateHandler = nil
                if let outcome {
                    continuation.resume(throwing: outcome)
                } else {
                    continuation.resume()
                }
            }
            connection.start(queue: queue)
        }
    }

    // MARK: - I/O

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Reads exactly `count` bytes from the TCP stream.
    func read(count: Int) async throws -> Data {
        while buffer.count < count {
            buffer.append(try await receiveChunk())
        }
        let result = Data(buffer.prefix(count))
        buffer.removeFirst(count)
        return result
    }

    /// Reads a Minecraft VarInt directly from the TCP stream.
    func readVarInt() async throws -> Int32 {
        var value: UInt32 = 0
        for index in 0..<5 {
            let byte = try await read(count: 1)[0]
            value |= UInt32(byte & 0x7F) << (7 * index)
            if byte & 0x80 == 0 { return Int32(bitPattern: value) }
        }
        throw ServerStatusError.parsingFailed("VarInt 過長")
    }

    /// Receives one UDP datagram.
    func receiveDatagram() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receiveMessage { data, _, _, error in
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else {
                    continuation.resume(returning: data ?? Data())
                }
            }
        }
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: ServerStatusError.networkFailed("伺服器提前關閉連線"))
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private static func mapError(_ error: NWError) -> ServerStatusError {
        switch error {
        case .posix(let code):
            .networkFailed(String(cString: strerror(code.rawValue)))
        case .dns:
            .networkFailed("無法解析主機名稱")
        default:
            .networkFailed(error.debugDescription)
        }
    }
}
