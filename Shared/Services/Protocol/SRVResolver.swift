//
//  SRVResolver.swift
//  MinecraftServerViewer
//
//  Looks up `_minecraft._tcp.<host>` SRV records through dnssd, the way the
//  Java client does when an address has no explicit port.
//

import Foundation
import dnssd

nonisolated enum SRVResolver {
    struct Target: Sendable, Equatable {
        var host: String
        var port: Int
    }

    /// Returns the preferred SRV target for `name`, or `nil` if there is none
    /// (no record, lookup error, or no answer within `timeout`).
    @concurrent
    static func resolve(_ name: String, timeout: Duration = .seconds(2)) async -> Target? {
        let records = await Query(name: name).run(timeout: timeout)
        // Lowest priority wins; among equals prefer the highest weight.
        return records
            .min { ($0.priority, -Int($0.weight)) < ($1.priority, -Int($1.weight)) }
            .map { Target(host: $0.target, port: Int($0.port)) }
    }

    fileprivate struct Record {
        var priority: UInt16
        var weight: UInt16
        var port: UInt16
        var target: String

        /// RDATA: priority, weight, port (big-endian UInt16) then the target as DNS labels.
        init?(rdata: UnsafeRawBufferPointer) {
            var reader = PacketReader(Data(rdata))
            guard let priority = try? reader.readUInt16(),
                  let weight = try? reader.readUInt16(),
                  let port = try? reader.readUInt16() else { return nil }

            var labels: [String] = []
            while let length = try? reader.readByte(), length > 0 {
                guard let bytes = try? reader.readBytes(Int(length)),
                      let label = String(bytes: bytes, encoding: .utf8) else { return nil }
                labels.append(label)
            }
            // A target of "." means the service is explicitly unavailable.
            guard !labels.isEmpty, port > 0 else { return nil }

            self.priority = priority
            self.weight = weight
            self.port = port
            target = labels.joined(separator: ".")
        }
    }

    /// One in-flight DNSServiceQueryRecord. All state is touched only on `queue`.
    private final class Query: @unchecked Sendable {
        private let name: String
        private let queue = DispatchQueue(label: "MinecraftServerViewer.SRVResolver")
        private var serviceRef: DNSServiceRef?
        private var records: [Record] = []
        private var continuation: CheckedContinuation<[Record], Never>?

        init(name: String) {
            self.name = name
        }

        func run(timeout: Duration) async -> [Record] {
            await withCheckedContinuation { continuation in
                queue.async {
                    self.continuation = continuation
                    self.start()
                    let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                    self.queue.asyncAfter(deadline: .now() + seconds) { self.finish() }
                }
            }
        }

        private func start() {
            let context = Unmanaged.passRetained(self).toOpaque()
            var ref: DNSServiceRef?
            let error = DNSServiceQueryRecord(
                &ref,
                DNSServiceFlags(kDNSServiceFlagsReturnIntermediates),
                0,
                name,
                UInt16(kDNSServiceType_SRV),
                UInt16(kDNSServiceClass_IN),
                { _, flags, _, errorCode, _, rrtype, _, rdlen, rdata, _, context in
                    guard let context else { return }
                    let query = Unmanaged<Query>.fromOpaque(context).takeUnretainedValue()
                    query.handle(flags: flags, errorCode: errorCode, rrtype: rrtype, rdata: rdata, length: rdlen)
                },
                context
            )
            guard error == kDNSServiceErr_NoError, let ref else {
                Unmanaged<Query>.fromOpaque(context).release()
                finish()
                return
            }
            serviceRef = ref
            DNSServiceSetDispatchQueue(ref, queue)
        }

        private func handle(flags: DNSServiceFlags, errorCode: DNSServiceErrorType, rrtype: UInt16, rdata: UnsafeRawPointer?, length: UInt16) {
            guard errorCode == kDNSServiceErr_NoError else {
                finish() // includes NoSuchRecord, delivered thanks to ReturnIntermediates
                return
            }
            if rrtype == UInt16(kDNSServiceType_SRV),
               flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0,
               let rdata,
               let record = Record(rdata: UnsafeRawBufferPointer(start: rdata, count: Int(length))) {
                records.append(record)
            }
            if flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) == 0, !records.isEmpty {
                finish()
            }
        }

        private func finish() {
            guard let continuation else { return }
            self.continuation = nil
            if let serviceRef {
                DNSServiceRefDeallocate(serviceRef)
                self.serviceRef = nil
                Unmanaged.passUnretained(self).release() // balances passRetained in start()
            }
            continuation.resume(returning: records)
        }
    }
}
