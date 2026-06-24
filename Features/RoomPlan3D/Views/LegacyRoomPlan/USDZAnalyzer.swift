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
            print("❌ Error: Could not find USDZ file: \(fileName)")
            return
        }
        
        print("📊 ANALYZING ROOM: \(fileName)")
        print("======================================")
        
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
            
        } catch {
            print("❌ Error loading USDZ file: \(error.localizedDescription)")
        }
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
        
        print("🔍 Found: \(walls.count) walls, \(floors.count) floors, \(ceilings.count) ceilings, \(doors.count) doors, \(windows.count) windows")
    }
    
    /// Analyzes wall dimensions and prints results
    private func analyzeWalls() {
        print("\n📏 WALL DIMENSIONS")
        print("--------------------------------------")
        
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
            print("Wall #\(index + 1) (\(wall.name ?? "unnamed")):")
            print("  • Length: \(formatMeasurement(length)) m")
            print("  • Height: \(formatMeasurement(wallHeight)) m")
            print("  • Thickness: \(formatMeasurement(thickness)) m")
            print("  • Area: \(formatMeasurement(area)) m²")
            print("  • Position: (\(formatMeasurement(wall.position.x)), \(formatMeasurement(wall.position.y)), \(formatMeasurement(wall.position.z)))")
        }
        
        print("\nTotal Wall Area: \(formatMeasurement(totalWallArea)) m²")
    }
    
    /// Analyzes floor dimensions and prints results
    private func analyzeFloors() {
        print("\n🔲 FLOOR DIMENSIONS")
        print("--------------------------------------")
        
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
            
            print("Floor #\(index + 1) (\(floor.name ?? "unnamed")):")
            print("  • Width: \(formatMeasurement(width)) m")
            print("  • Length: \(formatMeasurement(length)) m")
            print("  • Thickness: \(formatMeasurement(thickness)) m")
            print("  • Area: \(formatMeasurement(area)) m²")
        }
        
        print("\nTotal Floor Area: \(formatMeasurement(totalFloorArea)) m²")
    }
    
    /// Analyzes ceiling dimensions and prints results
    private func analyzeCeilings() {
        print("\n🔝 CEILING DIMENSIONS")
        print("--------------------------------------")
        
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
            
            print("Ceiling #\(index + 1) (\(ceiling.name ?? "unnamed")):")
            print("  • Width: \(formatMeasurement(width)) m")
            print("  • Length: \(formatMeasurement(length)) m")
            print("  • Thickness: \(formatMeasurement(thickness)) m")
            print("  • Height from floor: \(formatMeasurement(ceilingHeight)) m")
            print("  • Area: \(formatMeasurement(area)) m²")
        }
        
        if !ceilings.isEmpty {
            avgCeilingHeight /= Float(ceilings.count)
            print("\nAverage Ceiling Height: \(formatMeasurement(avgCeilingHeight)) m")
        }
        print("Total Ceiling Area: \(formatMeasurement(totalCeilingArea)) m²")
    }
    
    /// Analyzes door dimensions and prints results
    private func analyzeDoors() {
        if doors.isEmpty { return }
        
        print("\n🚪 DOOR DIMENSIONS")
        print("--------------------------------------")
        
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
            
            print("Door #\(index + 1) (\(door.name ?? "unnamed")):")
            print("  • Width: \(formatMeasurement(doorWidth)) m")
            print("  • Height: \(formatMeasurement(doorHeight)) m")
            print("  • Thickness: \(formatMeasurement(doorThickness)) m")
        }
    }
    
    /// Analyzes window dimensions and prints results
    private func analyzeWindows() {
        if windows.isEmpty { return }
        
        print("\n🪟 WINDOW DIMENSIONS")
        print("--------------------------------------")
        
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
            
            print("Window #\(index + 1) (\(window.name ?? "unnamed")):")
            print("  • Width: \(formatMeasurement(windowWidth)) m")
            print("  • Height: \(formatMeasurement(windowHeight)) m")
            print("  • Thickness: \(formatMeasurement(windowThickness)) m")
        }
    }
    
    /// Prints a summary of room measurements
    private func printRoomSummary() {
        print("\n📊 ROOM SUMMARY")
        print("======================================")
        
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
        
        print("• Room Width: \(formatMeasurement(roomWidth)) m")
        print("• Room Length: \(formatMeasurement(roomLength)) m")
        print("• Ceiling Height: \(formatMeasurement(avgCeilingHeight)) m")
        print("• Total Floor Area: \(formatMeasurement(totalFloorArea)) m²")
        print("• Number of Walls: \(walls.count)")
        print("• Number of Doors: \(doors.count)")
        print("• Number of Windows: \(windows.count)")
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
