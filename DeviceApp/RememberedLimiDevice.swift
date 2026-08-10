//
 //  RememberedLimiDevice.swift
 //  LIMI AI Device
 //
 //  Persists devices seen via Bonjour / linked API / cloud presence so they
 //  still appear when the phone is remote (Case 3 — cloud-only control).
 //

 import Foundation
 import SwiftData

 @Model
 final class RememberedLimiDevice {
     /// Hardware id (MAC / deviceId), uppercased preferred.
     @Attribute(.unique) var deviceID: String
     var displayName: String
     var channelCount: Int
     var channelTypesRaw: String
     var updatedAt: Date

     init(
         deviceID: String,
         displayName: String,
         channelCount: Int = 1,
         channelTypes: [String] = ["CCT"]
     ) {
         self.deviceID = deviceID.uppercased()
         self.displayName = displayName
         self.channelCount = max(channelCount, 1)
         self.channelTypesRaw = channelTypes.joined(separator: ",")
         self.updatedAt = Date()
     }

     var channelTypes: [String] {
         let parts = channelTypesRaw
             .split(separator: ",")
             .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
             .filter { $0 == "CCT" || $0 == "RGB" }
         return parts.isEmpty ? ["CCT"] : parts
     }
 }
