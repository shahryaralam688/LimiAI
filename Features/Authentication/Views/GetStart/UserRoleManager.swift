//
//  UserRoleManager.swift
//  Limi
//
//  Created by Mac Mini on 26/03/2025.
//


import SwiftUI

class UserRoleManager: ObservableObject {
    static let shared = UserRoleManager()
    
    @Published var currentRole: Role {
        didSet {
            UserDefaults.standard.setValue(currentRole.rawValue, forKey: "userRole")
        }
    }
    
    enum Role: String {
        case installer = "Installer"
        case user = "User"
        case productionUser = "Production User"
        case none = "None"
    }
    
    private init() {
        if let savedRole = UserDefaults.standard.string(forKey: "userRole"),
           let role = Role(rawValue: savedRole) {
            self.currentRole = role
        } else {
            self.currentRole = .none
        }
    }
    
    func setRole(_ role: Role) {
        currentRole = role
    }
}