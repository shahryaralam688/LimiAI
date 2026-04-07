//
//  ManagerAPI.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 12/11/2025.
//
import Foundation

struct APIConstants {
    
    // MARK: - Base URL
    static let baseURL = "https://dev.api.limitless-lighting.co.uk/"
    
    // Auth
    static let loginGoogle = baseURL + "client/google/login"
    static let LoginInstallerUser = baseURL + "client/installer_user"
    static let sendOTP = baseURL + "client/send_otp"
    static let verifyOTP = baseURL + "client/verify_otp"
    static let productionUser = baseURL + "client/verify_production"
    
    // AI Voice Assistant
    static let webHook = baseURL + "limi-ai/webhook"
    
    // Device
    static let deviceUser = baseURL + "client/devices/device_user" // add a device configurations
    static let addDeviceInfo = baseURL + "admin/add_master_controller_hub_device"
    static let getLinkDevices = baseURL + "client/devices/get_link_devices"
    static let processDeviceData = baseURL +  "client/devices/process_device_data"
    
    // AR 3d models download
    static let download3D = baseURL + " client/3d-models/web-configurator/download/"
    
    // RoomScan 3D model
    static let uploadRoom3DModel = baseURL + "client/3d-models"
    //get span for download 3d model
    static let lightConfigs = "https://dev.api1.limitless-lighting.co.uk/admin/products/light-configs/"
    // User Data
    static let userData = baseURL + "client/send_user_data"
    static let editProfile = baseURL + "client/update_profile"
    
}
