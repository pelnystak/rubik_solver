//
//  Cubie.swift
//  rubik_solver
//
//  Represents a single piece (cubie) of the Rubik's Cube
//

import Foundation
import SceneKit

/// Represents a single cubie (small cube piece) of the Rubik's Cube
/// A 3x3x3 cube has 26 visible cubies (excluding the invisible center)
class Cubie: Identifiable, ObservableObject {
    let id: UUID

    /// Position in the cube grid (0, 1, or 2 for each axis)
    @Published var x: Int
    @Published var y: Int
    @Published var z: Int

    /// Colors for each face (indexed by CubeFace)
    /// Order: up, down, front, back, right, left
    @Published var colors: [CubeColor]

    /// Reference to the SceneKit node representing this cubie
    weak var node: SCNNode?

    /// The type of cubie based on position
    var type: CubieType {
        let visibleFaces = countVisibleFaces()
        switch visibleFaces {
        case 3: return .corner
        case 2: return .edge
        case 1: return .center
        default: return .internal
        }
    }

    init(x: Int, y: Int, z: Int) {
        self.id = UUID()
        self.x = x
        self.y = y
        self.z = z
        self.colors = Cubie.initialColors(x: x, y: y, z: z)
    }

    /// Creates a copy of this cubie
    func copy() -> Cubie {
        let newCubie = Cubie(x: x, y: y, z: z)
        newCubie.colors = self.colors
        return newCubie
    }

    /// Returns the initial colors for a cubie at the given position
    static func initialColors(x: Int, y: Int, z: Int) -> [CubeColor] {
        var colors: [CubeColor] = Array(repeating: .black, count: 6)

        // Up face (y == 2)
        if y == 2 {
            colors[CubeFace.up.rawValue] = CubeFace.up.defaultColor
        }
        // Down face (y == 0)
        if y == 0 {
            colors[CubeFace.down.rawValue] = CubeFace.down.defaultColor
        }
        // Front face (z == 2)
        if z == 2 {
            colors[CubeFace.front.rawValue] = CubeFace.front.defaultColor
        }
        // Back face (z == 0)
        if z == 0 {
            colors[CubeFace.back.rawValue] = CubeFace.back.defaultColor
        }
        // Right face (x == 2)
        if x == 2 {
            colors[CubeFace.right.rawValue] = CubeFace.right.defaultColor
        }
        // Left face (x == 0)
        if x == 0 {
            colors[CubeFace.left.rawValue] = CubeFace.left.defaultColor
        }

        return colors
    }

    /// Counts how many faces are visible (not black)
    private func countVisibleFaces() -> Int {
        var count = 0
        if y == 2 { count += 1 } // Up
        if y == 0 { count += 1 } // Down
        if z == 2 { count += 1 } // Front
        if z == 0 { count += 1 } // Back
        if x == 2 { count += 1 } // Right
        if x == 0 { count += 1 } // Left
        return count
    }

    /// Rotates the cubie's colors around the X axis
    /// Used for R and L face moves
    func rotateColorsAroundX(clockwise: Bool) {
        let up = colors[CubeFace.up.rawValue]
        let down = colors[CubeFace.down.rawValue]
        let front = colors[CubeFace.front.rawValue]
        let back = colors[CubeFace.back.rawValue]

        if clockwise {
            colors[CubeFace.up.rawValue] = front
            colors[CubeFace.back.rawValue] = up
            colors[CubeFace.down.rawValue] = back
            colors[CubeFace.front.rawValue] = down
        } else {
            colors[CubeFace.up.rawValue] = back
            colors[CubeFace.front.rawValue] = up
            colors[CubeFace.down.rawValue] = front
            colors[CubeFace.back.rawValue] = down
        }
    }

    /// Rotates the cubie's colors around the Y axis
    /// Used for U and D face moves
    func rotateColorsAroundY(clockwise: Bool) {
        let front = colors[CubeFace.front.rawValue]
        let back = colors[CubeFace.back.rawValue]
        let right = colors[CubeFace.right.rawValue]
        let left = colors[CubeFace.left.rawValue]

        if clockwise {
            colors[CubeFace.front.rawValue] = right
            colors[CubeFace.left.rawValue] = front
            colors[CubeFace.back.rawValue] = left
            colors[CubeFace.right.rawValue] = back
        } else {
            colors[CubeFace.front.rawValue] = left
            colors[CubeFace.right.rawValue] = front
            colors[CubeFace.back.rawValue] = right
            colors[CubeFace.left.rawValue] = back
        }
    }

    /// Rotates the cubie's colors around the Z axis
    /// Used for F and B face moves
    func rotateColorsAroundZ(clockwise: Bool) {
        let up = colors[CubeFace.up.rawValue]
        let down = colors[CubeFace.down.rawValue]
        let right = colors[CubeFace.right.rawValue]
        let left = colors[CubeFace.left.rawValue]

        if clockwise {
            colors[CubeFace.up.rawValue] = left
            colors[CubeFace.right.rawValue] = up
            colors[CubeFace.down.rawValue] = right
            colors[CubeFace.left.rawValue] = down
        } else {
            colors[CubeFace.up.rawValue] = right
            colors[CubeFace.left.rawValue] = up
            colors[CubeFace.down.rawValue] = left
            colors[CubeFace.right.rawValue] = down
        }
    }

    /// Returns the position as a tuple
    var position: (Int, Int, Int) {
        return (x, y, z)
    }

    /// Returns true if this cubie is at the given position
    func isAt(x: Int, y: Int, z: Int) -> Bool {
        return self.x == x && self.y == y && self.z == z
    }

    /// Returns true if this cubie is on the specified face layer
    func isOnLayer(axis: Axis, index: Int) -> Bool {
        switch axis {
        case .x: return x == index
        case .y: return y == index
        case .z: return z == index
        }
    }

    /// Gets the color for a specific face
    func getColor(for face: CubeFace) -> CubeColor {
        return colors[face.rawValue]
    }

    /// Sets the color for a specific face
    func setColor(_ color: CubeColor, for face: CubeFace) {
        colors[face.rawValue] = color
    }
}

/// The type of cubie based on its position
enum CubieType {
    case corner    // 8 pieces with 3 visible faces
    case edge      // 12 pieces with 2 visible faces
    case center    // 6 pieces with 1 visible face
    case `internal`  // The invisible center piece
}
