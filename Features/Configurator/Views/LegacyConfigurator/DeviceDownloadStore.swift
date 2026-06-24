import Foundation

final class DeviceDownloadStore {
    static let shared = DeviceDownloadStore()

    private let storageKey = "device_download_map"
    private let queue = DispatchQueue(label: "DeviceDownloadStore.queue", attributes: .concurrent)
    private var _map: [String: String] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            _map = dict
        }
    }

    private func persist(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func set(downloadId: String, forMac mac: String) {
        queue.async(flags: .barrier) {
            self._map[mac] = downloadId
            self.persist(self._map)
        }
    }

    func get(forMac mac: String) -> String? {
        var value: String?
        queue.sync { value = self._map[mac] }
        return value
    }

    func remove(forMac mac: String) {
        queue.async(flags: .barrier) {
            self._map.removeValue(forKey: mac)
            self.persist(self._map)
        }
    }

    func all() -> [String: String] {
        var snapshot: [String: String] = [:]
        queue.sync { snapshot = self._map }
        return snapshot
    }

    func clear() {
        queue.async(flags: .barrier) {
            self._map.removeAll()
            self.persist(self._map)
        }
    }
}
