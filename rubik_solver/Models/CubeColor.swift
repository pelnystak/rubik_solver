//
//  CubeColor.swift
//  rubik_solver
//
//  Rubik's Cube color definitions with international standard colors
//

import SwiftUI
import SceneKit

/// Represents the six standard colors of a Rubik's Cube
/// following international color scheme
enum CubeColor: Int, CaseIterable, Codable {
    case white = 0   // Up face (top)
    case yellow = 1  // Down face (bottom)
    case green = 2   // Front face
    case blue = 3    // Back face
    case red = 4     // Right face
    case orange = 5  // Left face
    case black = 6   // Internal/hidden faces

    /// Returns the UIColor representation
    var uiColor: UIColor {
        switch self {
        case .white:
            return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        case .yellow:
            return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        case .green:
            return UIColor(red: 0.0, green: 0.62, blue: 0.38, alpha: 1.0)
        case .blue:
            return UIColor(red: 0.0, green: 0.32, blue: 0.73, alpha: 1.0)
        case .red:
            return UIColor(red: 0.72, green: 0.07, blue: 0.2, alpha: 1.0)
        case .orange:
            return UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 1.0)
        case .black:
            return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
    }

    /// Returns the SwiftUI Color representation
    var color: Color {
        Color(uiColor: uiColor)
    }

    /// Returns the name of the color
    var name: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .red: return "Red"
        case .orange: return "Orange"
        case .black: return "Black"
        }
    }

    /// Returns the single character representation
    var symbol: Character {
        switch self {
        case .white: return "W"
        case .yellow: return "Y"
        case .green: return "G"
        case .blue: return "B"
        case .red: return "R"
        case .orange: return "O"
        case .black: return "X"
        }
    }
}

/// Represents the six faces of the cube
enum CubeFace: Int, CaseIterable {
    case up = 0     // +Y (white)
    case down = 1   // -Y (yellow)
    case front = 2  // +Z (green)
    case back = 3   // -Z (blue)
    case right = 4  // +X (red)
    case left = 5   // -X (orange)

    /// Returns the default/solved color for this face
    var defaultColor: CubeColor {
        switch self {
        case .up: return .white
        case .down: return .yellow
        case .front: return .green
        case .back: return .blue
        case .right: return .red
        case .left: return .orange
        }
    }

    /// Returns the axis normal for this face
    var normal: SCNVector3 {
        switch self {
        case .up: return SCNVector3(0, 1, 0)
        case .down: return SCNVector3(0, -1, 0)
        case .front: return SCNVector3(0, 0, 1)
        case .back: return SCNVector3(0, 0, -1)
        case .right: return SCNVector3(1, 0, 0)
        case .left: return SCNVector3(-1, 0, 0)
        }
    }

    /// Returns the face name
    var name: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .front: return "Front"
        case .back: return "Back"
        case .right: return "Right"
        case .left: return "Left"
        }
    }
}
