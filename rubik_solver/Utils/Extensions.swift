//
//  Extensions.swift
//  rubik_solver
//
//  Utility extensions for SceneKit and mathematical operations
//

import Foundation
import SceneKit
import simd

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    /// Creates a vector with all components set to the same value
    init(_ value: Float) {
        self.init(x: value, y: value, z: value)
    }

    /// Returns the length of the vector
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }

    /// Returns a normalized version of the vector
    var normalized: SCNVector3 {
        let len = length
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }

    /// Dot product with another vector
    func dot(_ other: SCNVector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }

    /// Cross product with another vector
    func cross(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    /// Vector addition
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    /// Vector subtraction
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    /// Scalar multiplication
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    /// Scalar division
    static func / (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }

    /// Convert to simd_float3
    var simd: simd_float3 {
        return simd_float3(x, y, z)
    }
}

// MARK: - SCNVector4 Extensions

extension SCNVector4 {
    /// Creates a rotation vector from axis and angle
    init(axis: SCNVector3, angle: Float) {
        self.init(x: axis.x, y: axis.y, z: axis.z, w: angle)
    }

    /// Returns the axis component as SCNVector3
    var axis: SCNVector3 {
        return SCNVector3(x, y, z)
    }

    /// Returns the angle component
    var angle: Float {
        return w
    }
}

// MARK: - Quaternion Operations

struct Quaternion {
    var x: Float
    var y: Float
    var z: Float
    var w: Float

    /// Identity quaternion
    static var identity: Quaternion {
        return Quaternion(x: 0, y: 0, z: 0, w: 1)
    }

    /// Creates a quaternion from axis-angle representation
    init(axis: SCNVector3, angle: Float) {
        let halfAngle = angle / 2
        let sinHalf = sin(halfAngle)
        let normalizedAxis = axis.normalized
        self.x = normalizedAxis.x * sinHalf
        self.y = normalizedAxis.y * sinHalf
        self.z = normalizedAxis.z * sinHalf
        self.w = cos(halfAngle)
    }

    /// Creates a quaternion from components
    init(x: Float, y: Float, z: Float, w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    /// Creates a quaternion from SCNVector4 rotation
    init(rotation: SCNVector4) {
        self.init(axis: SCNVector3(rotation.x, rotation.y, rotation.z), angle: rotation.w)
    }

    /// Returns the length of the quaternion
    var length: Float {
        return sqrt(x * x + y * y + z * z + w * w)
    }

    /// Returns a normalized quaternion
    var normalized: Quaternion {
        let len = length
        guard len > 0 else { return .identity }
        return Quaternion(x: x / len, y: y / len, z: z / len, w: w / len)
    }

    /// Quaternion multiplication
    static func * (lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        return Quaternion(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
    }

    /// Converts to axis-angle representation (SCNVector4)
    func toAxisAngle() -> SCNVector4 {
        let normalized = self.normalized
        let angle = 2 * acos(normalized.w)

        if angle < 0.0001 {
            return SCNVector4(0, 1, 0, 0)
        }

        let s = sqrt(1 - normalized.w * normalized.w)
        if s < 0.0001 {
            return SCNVector4(normalized.x, normalized.y, normalized.z, angle)
        }

        return SCNVector4(
            normalized.x / s,
            normalized.y / s,
            normalized.z / s,
            angle
        )
    }

    /// Converts to SCNQuaternion
    var scnQuaternion: SCNQuaternion {
        return SCNQuaternion(x, y, z, w)
    }
}

// MARK: - SCNNode Extensions

extension SCNNode {
    /// Rotates the node by a quaternion
    func rotate(by quaternion: Quaternion) {
        let currentQuat = Quaternion(rotation: self.rotation)
        let newQuat = (quaternion * currentQuat).normalized
        self.rotation = newQuat.toAxisAngle()
    }

    /// Gets the current rotation as a quaternion
    var rotationQuaternion: Quaternion {
        return Quaternion(rotation: self.rotation)
    }

    /// Sets the rotation from a quaternion
    func setRotation(from quaternion: Quaternion) {
        self.rotation = quaternion.toAxisAngle()
    }

    /// Recursively removes all child nodes
    func removeAllChildrenRecursively() {
        for child in childNodes {
            child.removeAllChildrenRecursively()
            child.removeFromParentNode()
        }
    }
}

// MARK: - Float Extensions

extension Float {
    /// Converts degrees to radians
    var degreesToRadians: Float {
        return self * .pi / 180
    }

    /// Converts radians to degrees
    var radiansToDegrees: Float {
        return self * 180 / .pi
    }

    /// Clamps the value to a range
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    /// Converts to Float
    var float: Float {
        return Float(self)
    }
}

// MARK: - SCNMaterial Extensions

extension SCNMaterial {
    /// Creates a PBR material with the given color
    static func pbr(color: UIColor, roughness: CGFloat = 0.3, metalness: CGFloat = 0.0) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        material.locksAmbientWithDiffuse = true
        return material
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safely accesses an element at the given index
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
