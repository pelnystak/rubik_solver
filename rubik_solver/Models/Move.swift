//
//  Move.swift
//  rubik_solver
//
//  Rubik's Cube move definitions using Singmaster notation
//

import Foundation

/// Represents a single move type using Singmaster notation
/// Standard moves: U, D, F, B, R, L
/// Prime moves (counterclockwise): U', D', F', B', R', L'
/// Double moves: U2, D2, F2, B2, R2, L2
enum MoveType: String, CaseIterable, Codable {
    // Clockwise moves (90 degrees)
    case U = "U"   // Up face clockwise
    case D = "D"   // Down face clockwise
    case F = "F"   // Front face clockwise
    case B = "B"   // Back face clockwise
    case R = "R"   // Right face clockwise
    case L = "L"   // Left face clockwise

    // Counter-clockwise moves (prime, -90 degrees)
    case UPrime = "U'"
    case DPrime = "D'"
    case FPrime = "F'"
    case BPrime = "B'"
    case RPrime = "R'"
    case LPrime = "L'"

    // Double moves (180 degrees)
    case U2 = "U2"
    case D2 = "D2"
    case F2 = "F2"
    case B2 = "B2"
    case R2 = "R2"
    case L2 = "L2"

    /// The axis of rotation for this move
    var axis: Axis {
        switch self {
        case .U, .UPrime, .U2, .D, .DPrime, .D2:
            return .y
        case .F, .FPrime, .F2, .B, .BPrime, .B2:
            return .z
        case .R, .RPrime, .R2, .L, .LPrime, .L2:
            return .x
        }
    }

    /// The layer index (0, 1, or 2) affected by this move
    var layerIndex: Int {
        switch self {
        case .U, .UPrime, .U2: return 2
        case .D, .DPrime, .D2: return 0
        case .F, .FPrime, .F2: return 2
        case .B, .BPrime, .B2: return 0
        case .R, .RPrime, .R2: return 2
        case .L, .LPrime, .L2: return 0
        }
    }

    /// The rotation angle in radians (positive = clockwise when looking at face)
    var angle: Float {
        let baseAngle: Float = .pi / 2
        switch self {
        case .U, .B, .L:
            return -baseAngle
        case .D, .F, .R:
            return baseAngle
        case .UPrime, .BPrime, .LPrime:
            return baseAngle
        case .DPrime, .FPrime, .RPrime:
            return -baseAngle
        case .U2, .D2, .F2, .B2, .R2, .L2:
            return .pi
        }
    }

    /// Returns the inverse (opposite) move
    var inverse: MoveType {
        switch self {
        case .U: return .UPrime
        case .UPrime: return .U
        case .D: return .DPrime
        case .DPrime: return .D
        case .F: return .FPrime
        case .FPrime: return .F
        case .B: return .BPrime
        case .BPrime: return .B
        case .R: return .RPrime
        case .RPrime: return .R
        case .L: return .LPrime
        case .LPrime: return .L
        case .U2: return .U2
        case .D2: return .D2
        case .F2: return .F2
        case .B2: return .B2
        case .R2: return .R2
        case .L2: return .L2
        }
    }

    /// Returns true if this is a prime (counterclockwise) move
    var isPrime: Bool {
        switch self {
        case .UPrime, .DPrime, .FPrime, .BPrime, .RPrime, .LPrime:
            return true
        default:
            return false
        }
    }

    /// Returns true if this is a double move
    var isDouble: Bool {
        switch self {
        case .U2, .D2, .F2, .B2, .R2, .L2:
            return true
        default:
            return false
        }
    }

    /// Returns a random move
    static var random: MoveType {
        let basicMoves: [MoveType] = [.U, .D, .F, .B, .R, .L, .UPrime, .DPrime, .FPrime, .BPrime, .RPrime, .LPrime]
        return basicMoves.randomElement()!
    }

    /// Returns the base move (without prime or 2 suffix)
    var baseFace: String {
        return String(rawValue.prefix(1))
    }
}

/// Represents the three rotation axes
enum Axis {
    case x
    case y
    case z
}

/// Represents a recorded move with timestamp
struct Move: Codable, Identifiable {
    let id: UUID
    let type: MoveType
    let timestamp: Date

    init(type: MoveType) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
    }
}
