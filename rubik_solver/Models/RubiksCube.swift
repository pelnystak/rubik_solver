//
//  RubiksCube.swift
//  rubik_solver
//
//  Main Rubik's Cube model with complete game logic
//

import Foundation
import Combine

/// Main Rubik's Cube model managing state and logic
class RubiksCube: ObservableObject {
    /// The 26 cubies that make up the cube (excluding invisible center)
    @Published var cubies: [Cubie] = []

    /// History of all moves performed
    @Published var moveHistory: [Move] = []

    /// Number of moves made
    @Published var moveCount: Int = 0

    /// Whether the cube is currently solved
    @Published var isSolved: Bool = true

    /// Callback when a move is performed (for animation)
    var onMovePerformed: ((MoveType) -> Void)?

    /// Whether animations are currently blocked
    @Published var isAnimating: Bool = false

    init() {
        reset()
    }

    /// Resets the cube to the solved state
    func reset() {
        cubies.removeAll()

        // Create all 26 cubies (excluding center at 1,1,1)
        for x in 0...2 {
            for y in 0...2 {
                for z in 0...2 {
                    // Skip the invisible center piece
                    if x == 1 && y == 1 && z == 1 {
                        continue
                    }
                    let cubie = Cubie(x: x, y: y, z: z)
                    cubies.append(cubie)
                }
            }
        }

        moveHistory.removeAll()
        moveCount = 0
        isSolved = true
    }

    /// Performs a move and updates the cube state
    func performMove(_ moveType: MoveType, animated: Bool = true, recordHistory: Bool = true) {
        guard !isAnimating else { return }

        // Get affected cubies
        let affectedCubies = getCubiesForMove(moveType)

        // Rotate colors for each affected cubie
        for cubie in affectedCubies {
            rotateColors(cubie: cubie, moveType: moveType)
        }

        // Update positions
        updatePositions(moveType: moveType, cubies: affectedCubies)

        // Record the move
        if recordHistory {
            let move = Move(type: moveType)
            moveHistory.append(move)
            moveCount += 1
        }

        // Check if solved
        isSolved = checkIfSolved()

        // Trigger animation callback
        if animated {
            onMovePerformed?(moveType)
        }
    }

    /// Returns all cubies affected by a move
    func getCubiesForMove(_ moveType: MoveType) -> [Cubie] {
        let axis = moveType.axis
        let layerIndex = moveType.layerIndex

        return cubies.filter { cubie in
            cubie.isOnLayer(axis: axis, index: layerIndex)
        }
    }

    /// Rotates colors for a cubie based on move type
    private func rotateColors(cubie: Cubie, moveType: MoveType) {
        let isDouble = moveType.isDouble
        let rotationCount = isDouble ? 2 : 1

        for _ in 0..<rotationCount {
            switch moveType.axis {
            case .x:
                let clockwise = (moveType == .R || moveType == .LPrime ||
                               moveType == .R2 || moveType == .L2)
                cubie.rotateColorsAroundX(clockwise: clockwise)
            case .y:
                let clockwise = (moveType == .U || moveType == .DPrime ||
                               moveType == .U2 || moveType == .D2)
                cubie.rotateColorsAroundY(clockwise: clockwise)
            case .z:
                let clockwise = (moveType == .F || moveType == .BPrime ||
                               moveType == .F2 || moveType == .B2)
                cubie.rotateColorsAroundZ(clockwise: clockwise)
            }
        }
    }

    /// Updates positions of cubies after a move
    private func updatePositions(moveType: MoveType, cubies: [Cubie]) {
        let isDouble = moveType.isDouble
        let rotationCount = isDouble ? 2 : 1

        for _ in 0..<rotationCount {
            for cubie in cubies {
                let (newX, newY, newZ) = calculateNewPosition(
                    x: cubie.x, y: cubie.y, z: cubie.z,
                    moveType: moveType
                )
                cubie.x = newX
                cubie.y = newY
                cubie.z = newZ
            }
        }
    }

    /// Calculates new position after a single 90-degree rotation
    private func calculateNewPosition(x: Int, y: Int, z: Int, moveType: MoveType) -> (Int, Int, Int) {
        switch moveType.axis {
        case .y:
            // Rotation around Y axis
            let clockwise = (moveType == .U || moveType == .DPrime || moveType == .U2 || moveType == .D2)
            if clockwise {
                return (2 - z, y, x)
            } else {
                return (z, y, 2 - x)
            }
        case .x:
            // Rotation around X axis
            let clockwise = (moveType == .R || moveType == .LPrime || moveType == .R2 || moveType == .L2)
            if clockwise {
                return (x, z, 2 - y)
            } else {
                return (x, 2 - z, y)
            }
        case .z:
            // Rotation around Z axis
            let clockwise = (moveType == .F || moveType == .BPrime || moveType == .F2 || moveType == .B2)
            if clockwise {
                return (y, 2 - x, z)
            } else {
                return (2 - y, x, z)
            }
        }
    }

    /// Checks if the cube is in solved state
    func checkIfSolved() -> Bool {
        // Check each face has uniform color
        for face in CubeFace.allCases {
            let expectedColor = face.defaultColor
            let faceCubies = getCubiesOnFace(face)

            for cubie in faceCubies {
                if cubie.getColor(for: face) != expectedColor {
                    return false
                }
            }
        }
        return true
    }

    /// Returns all cubies on a specific face
    func getCubiesOnFace(_ face: CubeFace) -> [Cubie] {
        switch face {
        case .up:
            return cubies.filter { $0.y == 2 }
        case .down:
            return cubies.filter { $0.y == 0 }
        case .front:
            return cubies.filter { $0.z == 2 }
        case .back:
            return cubies.filter { $0.z == 0 }
        case .right:
            return cubies.filter { $0.x == 2 }
        case .left:
            return cubies.filter { $0.x == 0 }
        }
    }

    /// Undoes the last move
    func undoLastMove() {
        guard !moveHistory.isEmpty, !isAnimating else { return }

        let lastMove = moveHistory.removeLast()
        let inverseMove = lastMove.type.inverse

        // Perform inverse move without recording
        performMove(inverseMove, animated: true, recordHistory: false)
        moveCount = max(0, moveCount - 1)
    }

    /// Scrambles the cube with random moves
    func scramble(moves: Int = 25) {
        guard !isAnimating else { return }

        var previousMove: MoveType?

        for _ in 0..<moves {
            var move: MoveType

            // Avoid same face consecutive moves
            repeat {
                move = MoveType.random
            } while previousMove != nil && move.baseFace == previousMove!.baseFace

            performMove(move, animated: false, recordHistory: true)
            previousMove = move
        }

        isSolved = checkIfSolved()
    }

    /// Returns the cubie at the specified position
    func getCubie(at x: Int, _ y: Int, _ z: Int) -> Cubie? {
        return cubies.first { $0.isAt(x: x, y: y, z: z) }
    }

    /// Returns move history as a string
    var moveHistoryString: String {
        return moveHistory.map { $0.type.rawValue }.joined(separator: " ")
    }
}
