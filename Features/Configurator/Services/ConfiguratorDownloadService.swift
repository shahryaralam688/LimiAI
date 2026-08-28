import Foundation
import Network

/// Single download path for configurator USDZ models (Phase J).
enum ConfiguratorDownloadService {
    enum Outcome {
        case alreadyCached(URL)
        case downloaded(URL)
        case failed(Error)
        case skippedNoNetwork
    }

    static func isCached(snapId: String) -> Bool {
        ConfiguratorModelStore.fileExists(forSnapId: snapId)
    }

    static func downloadIfNeeded(
        snapId: String,
        requireNetworkWhenMissing: Bool = false,
        completion: @escaping (Outcome) -> Void
    ) {
        if isCached(snapId: snapId) {
            let url = ConfiguratorModelStore.resolvedURL(forSnapId: snapId)
            completion(.alreadyCached(url))
            return
        }

        if requireNetworkWhenMissing {
            checkNetwork { hasNetwork in
                guard hasNetwork else {
                    completion(.skippedNoNetwork)
                    return
                }
                performDownload(snapId: snapId, completion: completion)
            }
        } else {
            performDownload(snapId: snapId, completion: completion)
        }
    }

    private static func performDownload(
        snapId: String,
        completion: @escaping (Outcome) -> Void
    ) {
        LimiConfiguratorAPI.downloadUSDZ(downloadId: snapId) { result in
            switch result {
            case .success(let data):
                do {
                    try ConfiguratorModelStore.save(data, forSnapId: snapId)
                    let url = ConfiguratorModelStore.url(forSnapId: snapId)
                    completion(.downloaded(url))
                } catch {
                    completion(.failed(error))
                }
            case .failure(let error):
                completion(.failed(error))
            }
        }
    }

    private static func checkNetwork(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "ConfiguratorDownloadService.Network")
        monitor.pathUpdateHandler = { path in
            completion(path.status == .satisfied)
            monitor.cancel()
        }
        monitor.start(queue: queue)
    }
}
