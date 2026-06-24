import Foundation

// MARK: - Global Variables for LimiteLess Exhibition App

/// Global user space variable (home or hospitality)
var globalUserSpace: String {
    get {
        return UserDefaults.standard.string(forKey: "globalUserSpace") ?? "Default User"
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "globalUserSpace")
    }
}

/// Global user location variable (latitude,longitude format)
var globalUserLocation: String {
    get {
        return UserDefaults.standard.string(forKey: "globalUserLocation") ?? ""
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "globalUserLocation")
    }
}
