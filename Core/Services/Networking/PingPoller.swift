import Foundation
import Darwin

// MARK: - ICMP Ping wrapper (SimplePing-based)
final class PingPoller: NSObject {
    struct Config {
        let maxAttempts: Int
        let gapBetween: TimeInterval
        let perAttemptTimeout: TimeInterval
    }

    private let host: String
    private let uuid: String
    private let config: Config
    private var currentAttempt = 0
    private var ping: SimplePing?
    private var timeoutTimer: Timer?
    private var gapTimer: Timer?
    private let completion: (String, Bool) -> Void

    init(host: String, uuid: String, config: Config, completion: @escaping (String, Bool) -> Void) {
        self.host = host
        self.uuid = uuid
        self.config = config
        self.completion = completion
        super.init()
    }

    func start() { scheduleNextAttempt() }

    func cancel() {
        invalidateTimers()
        ping?.stop()
        ping = nil
    }

    private func scheduleNextAttempt() {
        if currentAttempt >= config.maxAttempts {
            completion(uuid, false)
            return
        }
        currentAttempt += 1
        let p = SimplePing(hostName: host)
        p?.delegate = self
        p?.start()
        ping = p
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: config.perAttemptTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.ping?.stop()
            self.ping = nil
            self.scheduleGapThenNextAttempt()
        }
    }

    private func scheduleGapThenNextAttempt() {
        gapTimer = Timer.scheduledTimer(withTimeInterval: config.gapBetween, repeats: false) { [weak self] _ in
            self?.scheduleNextAttempt()
        }
    }

    private func invalidateTimers() {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        gapTimer?.invalidate(); gapTimer = nil
    }
}

extension PingPoller: SimplePingDelegate {
    @objc func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) { pinger.send(with: nil) }
    @objc func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        invalidateTimers()
        pinger.stop()
        scheduleGapThenNextAttempt()
    }
    @objc func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {}
    @objc func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        invalidateTimers()
        pinger.stop()
        completion(uuid, true)
    }
    @objc func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        invalidateTimers()
        pinger.stop()
        completion(uuid, true)
    }
}
