//
//  USDZAnalyzer.swift
//  ForReal Demo
//
//  Created by Vatsal Patel on 8/17/24.
//

import Foundation
import SceneKit
import RoomPlan

class USDZAnalyzer {
    
    // MARK: - Properties
    
    private var scene: SCNScene?
    private var walls: [SCNNode] = []
    private var floors: [SCNNode] = []
    private var ceilings: [SCNNode] = []
    private var doors: [SCNNode] = []
    private var windows: [SCNNode] = []
    private var objects: [SCNNode] = []
    
    // MARK: - Public Methods
    
    /// Analyzes a USDZ file and prints dimensions to console
    /// - Parameter fileName: Name of the USDZ file to analyze
    func analyzeUSDZFile(fileName: String) {
        guard let url = RoominatorFileManager.shared.getUSDZFileURL(for: fileName) else {
            return
        }
        
        
        do {
            // Load the USDZ file as a SceneKit scene
            scene = try SCNScene(url: url, options: nil)
            
            // Categorize nodes
            categorizeNodes()
            
            // Analyze and print dimensions
            analyzeWalls()
            analyzeFloors()
            analyzeCeilings()
            analyzeDoors()
            analyzeWindows()
            
            // Print summary
            printRoomSummary()
            
        } catch { /* ignored */ }
    }
    
    // MARK: - Private Methods
    
    /// Categorizes nodes in the scene by type
    private func categorizeNodes() {
        guard let scene = scene else { return }
        
        // Reset arrays
        walls = []
        floors = []
        ceilings = []
        doors = []
        windows = []
        objects = []
        
        // Traverse the scene hierarchy
        scene.rootNode.enumerateChildNodes { (node, _) in
            guard let name = node.name else { return }
            
            if name.hasPrefix("Wall") {
                walls.append(node)
            } else if name.hasPrefix("Floor") {
                floors.append(node)
            } else if name.hasPrefix("Ceiling") {
                ceilings.append(node)
            } else if name.hasPrefix("Door") {
                doors.append(node)
            } else if name.hasPrefix("Window") {
                windows.append(node)
            } else if node.geometry != nil {
                objects.append(node)
            }
        }
        
    }
    
    /// Analyzes wall dimensions and prints results
    private func analyzeWalls() {
        
        var totalWallArea: Float = 0
        
        for (index, wall) in walls.enumerated() {
            guard let geometry = wall.geometry else { continue }
            
            // Get bounding box
            let (min, max) = geometry.boundingBox
            
            // Calculate dimensions
            let width = abs(max.x - min.x)
            let height = abs(max.y - min.y)
            let depth = abs(max.z - min.z)
            
            // Determine wall orientation and dimensions
            let (length, wallHeight, thickness) = determineWallDimensions(width, height, depth)
            let area = length * wallHeight
            totalWallArea += area
            
            // Print wall information
        }
        
    }
    
    /// Analyzes floor dimensions and prints results
    private func analyzeFloors() {
        
        var totalFloorArea: Float = 0
        
        for (index, floor) in floors.enumerated() {
            guard let geometry = floor.geometry else { continue }
            
            // Get bounding box
            let (min, max) = geometry.boundingBox
            
            // Calculate dimensions
            let width = abs(max.x - min.x)
            let length = abs(max.z - min.z)
            let thickness = abs(max.y - min.y)
            
            let area = width * length
            totalFloorArea += area
            
        }
        
    }
    
    /// Analyzes ceiling dimensions and prints results
    private func analyzeCeilings() {
        
        var totalCeilingArea: Float = 0
        var avgCeilingHeight: Float = 0
        
        for (index, ceiling) in ceilings.enumerated() {
            guard let geometry = ceiling.geometry else { continue }
            
            // Get bounding box
            let (min, max) = geometry.boundingBox
            
            // Calculate dimensions
            let width = abs(max.x - min.x)
            let length = abs(max.z - min.z)
            let thickness = abs(max.y - min.y)
            
            let area = width * length
            totalCeilingArea += area
            
            // Calculate ceiling height (y-position)
            let ceilingHeight = ceiling.position.y
            avgCeilingHeight += ceilingHeight
            
        }
        
        if !ceilings.isEmpty {
            avgCeilingHeight /= Float(ceilings.count)
        }
    }
    
    /// Analyzes door dimensions and prints results
    private func analyzeDoors() {
        if doors.isEmpty { return }
        
        
        for (index, door) in doors.enumerated() {
            guard let geometry = door.geometry else { continue }
            
            // Get bounding box
            let (min, max) = geometry.boundingBox
            
            // Calculate dimensions
            let width = abs(max.x - min.x)
            let height = abs(max.y - min.y)
            let depth = abs(max.z - min.z)
            
            // Determine door dimensions based on orientation
            let (doorWidth, doorHeight, doorThickness) = determineDoorDimensions(width, height, depth)
            
        }
    }
    
    /// Analyzes window dimensions and prints results
    private func analyzeWindows() {
        if windows.isEmpty { return }
        
        
        for (index, window) in windows.enumerated() {
            guard let geometry = window.geometry else { continue }
            
            // Get bounding box
            let (min, max) = geometry.boundingBox
            
            // Calculate dimensions
            let width = abs(max.x - min.x)
            let height = abs(max.y - min.y)
            let depth = abs(max.z - min.z)
            
            // Determine window dimensions based on orientation
            let (windowWidth, windowHeight, windowThickness) = determineWindowDimensions(width, height, depth)
            
        }
    }
    
    /// Prints a summary of room measurements
    private func printRoomSummary() {
        
        // Calculate total floor area
        var totalFloorArea: Float = 0
        for floor in floors {
            guard let geometry = floor.geometry else { continue }
            let (min, max) = geometry.boundingBox
            let width = abs(max.x - min.x)
            let length = abs(max.z - min.z)
            totalFloorArea += width * length
        }
        
        // Calculate average ceiling height
        var avgCeilingHeight: Float = 0
        if !ceilings.isEmpty {
            for ceiling in ceilings {
                avgCeilingHeight += ceiling.position.y
            }
            avgCeilingHeight /= Float(ceilings.count)
        }
        
        // Calculate room dimensions (approximate)
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for wall in walls {
            minX = min(minX, wall.position.x)
            maxX = max(maxX, wall.position.x)
            minZ = min(minZ, wall.position.z)
            maxZ = max(maxZ, wall.position.z)
        }
        
        let roomWidth = maxX - minX
        let roomLength = maxZ - minZ
        
    }
    
    // MARK: - Helper Methods
    
    /// Determines wall dimensions based on orientation
    private func determineWallDimensions(_ width: Float, _ height: Float, _ depth: Float) -> (length: Float, height: Float, thickness: Float) {
        // Determine which dimension is the smallest (thickness)
        let dimensions = [width, height, depth]
        let minDimension = dimensions.min() ?? 0.01
        
        if minDimension == width {
            // Wall is oriented along Y-Z plane
            return (depth, height, width)
        } else if minDimension == depth {
            // Wall is oriented along X-Y plane
            return (width, height, depth)
        } else {
            // Wall is oriented along X-Z plane (horizontal wall or partition)
            return (width, depth, height)
        }
    }
    
    /// Determines door dimensions based on orientation
    private func determineDoorDimensions(_ width: Float, _ height: Float, _ depth: Float) -> (width: Float, height: Float, thickness: Float) {
        // Determine which dimension is the smallest (thickness)
        let dimensions = [width, height, depth]
        let minDimension = dimensions.min() ?? 0.01
        
        if minDimension == depth {
            // Door is oriented along X-Y plane
            return (width, height, depth)
        } else if minDimension == width {
            // Door is oriented along Y-Z plane
            return (depth, height, width)
        } else {
            // Unusual orientation
            return (width, depth, height)
        }
    }
    
    /// Determines window dimensions based on orientation
    private func determineWindowDimensions(_ width: Float, _ height: Float, _ depth: Float) -> (width: Float, height: Float, thickness: Float) {
        // Similar to door dimensions
        return determineDoorDimensions(width, height, depth)
    }
    
    /// Formats a measurement to 2 decimal places
    private func formatMeasurement(_ value: Float) -> String {
        return String(format: "%.2f", value)
    }
}
