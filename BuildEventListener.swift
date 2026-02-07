//
//  BuildEventListener.swift
//  NotchRuntimeToolsForDevs
//
//  Created by Nizar TURKI on 06/02/2026.
//

import Foundation
import Network

/// Lightweight TCP listener on localhost that accepts newline-delimited JSON payloads.
final class BuildEventListener {
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.notchruntime.listener")
    private var listener: NWListener?

    var onPayload: ((BuildEventPayload) -> Void)?

    init() {
        let envHost = ProcessInfo.processInfo.environment["NOTCH_BUILD_HOST"]
        let envPort = ProcessInfo.processInfo.environment["NOTCH_BUILD_PORT"]
        self.host = NWEndpoint.Host(envHost ?? "127.0.0.1")
        self.port = NWEndpoint.Port(rawValue: UInt16(envPort ?? "34345") ?? 34345)!
    }

    func start() {
        stop()
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: params, on: port)
        } catch {
            NSLog("BuildEventListener: failed to create listener \(error)")
            return
        }
        listener?.service = nil
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener?.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                NSLog("BuildEventListener: failed \(error)")
            case .ready:
                NSLog("BuildEventListener: listening on \(self.host):\(self.port)")
            default:
                break
            }
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()

        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    buffer.append(data)
                    self.drainBuffer(&buffer)
                }
                if isComplete || error != nil {
                    connection.cancel()
                    return
                }
                receive()
            }
        }
        receive()
    }

    private func drainBuffer(_ buffer: inout Data) {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let packet = buffer.prefix(upTo: newlineIndex)
            buffer.removeSubrange(...newlineIndex)
            guard !packet.isEmpty else { continue }
            decode(payloadData: packet)
        }
    }

    private func decode(payloadData: Data) {
        guard let payload = try? JSONDecoder().decode(BuildEventPayload.self, from: payloadData) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onPayload?(payload)
        }
    }
}
