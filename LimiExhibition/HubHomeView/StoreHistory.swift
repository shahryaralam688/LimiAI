//
//  StoreHistory.swift
//  Limi
//
//  Created by Mac Mini on 20/03/2025.
//
import Foundation
import Combine
import SwiftUI

typealias ByteArray = [UInt8]

struct QueueElement: Codable {
    let hub: Hub
    let byteArray: ByteArray

    func formattedByteArray() -> String {
        return byteArray.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
    }
}

class StoreHistory: ObservableObject {
    @Published private(set) var queues: [UUID: [QueueElement]] = [:]
    private let maxQueueSize = 5
    private let storageKey = "storeHistoryQueues"
    
    init() {
        loadQueues()
    }
    
    var isQueueFull: Bool {
        guard let queue = queues.values.first else { return false }
        return queue.count >= maxQueueSize
    }
    

    
    func addElement(hub: Hub, byteArray: ByteArray) {
        let newElement = QueueElement(hub: hub, byteArray: byteArray)
        var queue = queues[hub.id] ?? []
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        queue.append(newElement)
        queues[hub.id] = queue
        saveQueues()
    }
    

    
    private func saveQueues() {
        if let encoded = try? JSONEncoder().encode(queues) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadQueues() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loadedQueues = try? JSONDecoder().decode([UUID: [QueueElement]].self, from: data) else {
            return
        }
        queues = loadedQueues
    }
}
