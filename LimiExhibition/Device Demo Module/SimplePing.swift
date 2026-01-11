//
//  SimplePingDelegate.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 02/11/2025.
//


//
//  SimplePing.swift
//  Minimal Swift ICMP (IPv4) pinger compatible with Apple's SimplePing delegate style
//
//  Drop this into your target. Works on iOS/tvOS/macOS.
//  Limitations: IPv4 only; one socket per instance; single-host pinger.
//

import Foundation
import Darwin

// MARK: - Delegate

@objc public protocol SimplePingDelegate: AnyObject {
    /// Called after `start()` when the socket and destination address are ready.
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data)
    /// Called if the pinger fails irrecoverably (e.g. DNS/addr parse/socket/error).
    func simplePing(_ pinger: SimplePing, didFailWithError error: Error)
    /// Called right after the echo request is sent.
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16)
    /// Called when we receive an echo reply matching our identifier.
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16)
    /// Called for packets that arrive but are not our echo reply (different id/type/etc).
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data)
}

// Provide empty default impls so conformers can implement only what they need
public extension SimplePingDelegate {
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {}
    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {}
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {}
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {}
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {}
}

// MARK: - ICMP structures

private struct ICMPHeader {
    var type: UInt8      // 8 = echo request, 0 = echo reply
    var code: UInt8      // always 0 for echo
    var checksum: UInt16 // 1's complement over header + payload
    var identifier: UInt16
    var sequenceNumber: UInt16
}

private func icmpChecksum(_ data: Data) -> UInt16 {
    var sum: UInt32 = 0
    var idx = 0
    let count = data.count
    data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        while idx + 1 < count {
            let word = UInt16(ptr[idx]) << 8 | UInt16(ptr[idx + 1])
            sum &+= UInt32(word)
            idx += 2
        }
        if idx < count {
            let last = UInt16(ptr[idx]) << 8
            sum &+= UInt32(last)
        }
    }
    // fold 32-bit sum to 16 bits
    while (sum >> 16) != 0 {
        sum = (sum & 0xFFFF) &+ (sum >> 16)
    }
    return ~UInt16(sum & 0xFFFF)
}

// MARK: - Pinger

public final class SimplePing: NSObject {
    public weak var delegate: SimplePingDelegate?

    private let hostName: String
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var destAddr: sockaddr_in?
    private var started = false

    // Echo identification
    private let identifier: UInt16 = UInt16(getpid() & 0xFFFF)
    private var sequence: UInt16 = 0

    // Packet sizing
    private let payloadSize = 56 // bytes (like system ping)

    public init?(hostName: String) {
        guard !hostName.isEmpty else { return nil }
        self.hostName = hostName
    }

    deinit {
        stop()
    }

    // MARK: Start/Stop

    public func start() {
        guard !started else { return }
        started = true

        // Parse IPv4 address text (we expect an IP string, not a DNS name)
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        let cstr = (hostName as NSString).utf8String
        if inet_pton(AF_INET, cstr, &addr.sin_addr) != 1 {
            started = false
            let err = NSError(domain: "SimplePing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Host is not an IPv4 address: \(hostName)"])
            delegate?.simplePing(self, didFailWithError: err)
            return
        }

        // Unprivileged ICMP on iOS: SOCK_DGRAM with IPPROTO_ICMP works for echo
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        if fd < 0 {
            started = false
            let err = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "socket() failed: \(errno)"])
            delegate?.simplePing(self, didFailWithError: err)
            return
        }

        // Non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        socketFD = fd
        destAddr = addr

        // Install read source
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            self?.handleRead()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.socketFD >= 0 {
                close(self.socketFD)
                self.socketFD = -1
            }
        }
        readSource = source
        source.resume()

        // Notify delegate
        var addrCopy = addr
        let data = Data(bytes: &addrCopy, count: MemoryLayout<sockaddr_in>.size)
        delegate?.simplePing(self, didStartWithAddress: data)
    }

    public func stop() {
        readSource?.cancel()
        readSource = nil
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        started = false
    }

    // MARK: Send Echo

    /// Sends one ICMP echo request packet.
    /// - Parameter _: optional payload (will be appended after header).
    public func send(with payload: Data?) {
        guard started, socketFD >= 0, var addr = destAddr else { return }

        sequence &+= 1

        // Build ICMP header
        var header = ICMPHeader(
            type: 8, // echo request
            code: 0,
            checksum: 0,
            identifier: CFSwapInt16HostToBig(identifier),
            sequenceNumber: CFSwapInt16HostToBig(sequence)
        )

        var packet = Data(bytes: &header, count: MemoryLayout<ICMPHeader>.size)
        if let p = payload {
            packet.append(p)
        } else {
            // Default payload: timestamp + padding
            var ts = UInt64(Date().timeIntervalSince1970 * 1000)
            withUnsafeBytes(of: &ts) { packet.append(contentsOf: $0) }
            if payloadSize > 8 {
                packet.append(Data(repeating: 0x42, count: payloadSize - 8))
            }
        }

        // Compute checksum over the full packet
        var mutable = packet
        mutable.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            // checksum field is at bytes 2..3
            ptr[2] = 0
            ptr[3] = 0
        }
        let csum = icmpChecksum(mutable)
        var csumBE = CFSwapInt16HostToBig(csum)
        withUnsafeBytes(of: &csumBE) { bytes in
            mutable.replaceSubrange(2..<4, with: bytes)
        }

        // Send
        let sent: ssize_t = mutable.withUnsafeBytes { raw in
            var sa = sockaddr()
            memcpy(&sa, &addr, MemoryLayout<sockaddr_in>.size)
            return withUnsafePointer(to: &sa) { saptr in
                saptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                    sendto(socketFD, raw.baseAddress, mutable.count, 0, sp, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        if sent < 0 {
            let err = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "sendto() failed: \(errno)"])
            delegate?.simplePing(self, didFailWithError: err)
            return
        }

        delegate?.simplePing(self, didSendPacket: mutable, sequenceNumber: sequence)
    }

    // MARK: Read/Parse

    private func handleRead() {
        // Read once; if multiple packets pending, the source will re-fire.
        var buf = [UInt8](repeating: 0, count: 4096)
        var from = sockaddr_storage()
        var fromLen: socklen_t = socklen_t(MemoryLayout<sockaddr_storage>.size)

        let count = withUnsafeMutablePointer(to: &from) { ptr -> ssize_t in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                return recvfrom(socketFD, &buf, buf.count, 0, sp, &fromLen)
            }
        }

        if count <= 0 { return }

        let packet = Data(bytes: buf, count: count)
        // Parse IPv4 packet: first is IP header, then ICMP
        guard count >= 20 else {
            delegate?.simplePing(self, didReceiveUnexpectedPacket: packet)
            return
        }

        let ipHeaderLen = Int((buf[0] & 0x0F) * 4)
        guard ipHeaderLen >= 20, count >= ipHeaderLen + MemoryLayout<ICMPHeader>.size else {
            delegate?.simplePing(self, didReceiveUnexpectedPacket: packet)
            return
        }

        // ICMP section starts after IPv4 header
        let icmpOffset = ipHeaderLen
        let icmpData = packet.subdata(in: icmpOffset..<count)

        // Read type, code, checksum, identifier, sequence
        let type = icmpData[icmpData.startIndex]
        // let code = icmpData[icmpData.startIndex + 1] // not used
        let idBE = icmpData.subdata(in: 4..<6)
        let seqBE = icmpData.subdata(in: 6..<8)
        let id = idBE.withUnsafeBytes { $0.load(as: UInt16.self) }
        let seq = seqBE.withUnsafeBytes { $0.load(as: UInt16.self) }
        let idHost = CFSwapInt16BigToHost(id)
        let seqHost = CFSwapInt16BigToHost(seq)

        if type == 0 /* echo reply */ && idHost == identifier {
            delegate?.simplePing(self, didReceivePingResponsePacket: icmpData, sequenceNumber: seqHost)
        } else {
            delegate?.simplePing(self, didReceiveUnexpectedPacket: packet)
        }
    }
}
