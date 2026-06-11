//
//  MQTTClientProtocol.swift
//  Limi
//
//  Abstraction over the "MQTT door". Today we ship one implementation:
//  SocketIOMQTTBridge (re-uses LightControllingSocket → backend → MQTT).
//
//  When/if a real broker client is added (e.g. CocoaMQTT), drop a new file
//  conforming to this protocol and assign it to LimiTransport.
//

import Foundation
import Combine

/// Anything that can publish a Limi command on the MQTT door.
public protocol MQTTClient: AnyObject, MQTTPresenceProviding {
    /// Publish a fully-encoded command envelope to `device/<deviceId>/command`.
    /// Throws if the underlying transport is not currently connected.
    func publishCommand(_ payload: Data, deviceId: String) async throws

    /// Publish a reset to `device/<deviceId>/reset`. Reset MUST never be mixed
    /// into the command topic.
    func publishReset(deviceId: String) async throws
}
