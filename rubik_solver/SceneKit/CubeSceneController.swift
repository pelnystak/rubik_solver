//
//  CubeSceneController.swift
//  rubik_solver
//
//  Manages the SceneKit scene and animations for the Rubik's Cube
//

import SceneKit
import Combine

/// Controls the 3D scene and handles animations
class CubeSceneController: ObservableObject {
    /// The SceneKit scene
    let scene: SCNScene

    /// Reference to the cube model
    weak var cube: RubiksCube?

    /// The renderer for creating cube geometry
    let renderer: CubeRenderer

    /// Root node for the cube (for rotation)
    var cubeRootNode: SCNNode

    /// Camera node
    var cameraNode: SCNNode?

    /// Animation duration for moves
    let animationDuration: TimeInterval = 0.3

    /// Whether animation is in progress
    @Published var isAnimating: Bool = false

    /// Camera distance constraints
    let minCameraDistance: Float = 5.0
    let maxCameraDistance: Float = 15.0
    let defaultCameraDistance: Float = 10.0

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.scene = SCNScene()
        self.renderer = CubeRenderer()
        self.cubeRootNode = SCNNode()
        self.cubeRootNode.name = "cubeRoot"

        setupScene()
    }

    /// Sets up the initial scene
    private func setupScene() {
        // Add cube root node
        scene.rootNode.addChildNode(cubeRootNode)

        // Setup lighting
        renderer.setupLighting(scene: scene)

        // Setup camera
        cameraNode = renderer.setupCamera(scene: scene)

        // Setup background
        renderer.setupBackground(scene: scene)

        // Add floor (optional)
        // let floor = renderer.createFloor()
        // scene.rootNode.addChildNode(floor)

        // Set initial rotation for better view
        let initialRotation = Quaternion(axis: SCNVector3(1, 0, 0), angle: 0.3)
        let secondRotation = Quaternion(axis: SCNVector3(0, 1, 0), angle: -0.5)
        let combined = secondRotation * initialRotation
        cubeRootNode.rotation = combined.toAxisAngle()
    }

    /// Builds/rebuilds the cube from the model
    func buildCube(from model: RubiksCube) {
        self.cube = model

        // Remove existing cubie nodes
        cubeRootNode.childNodes.filter { $0.name?.starts(with: "cubie_") ?? false }
            .forEach { $0.removeFromParentNode() }

        // Create nodes for each cubie
        for cubie in model.cubies {
            let node = renderer.createCubieNode(for: cubie)
            cubeRootNode.addChildNode(node)
        }

        // Setup move callback - receives pre-computed affected cubies
        model.onMovePerformed = { [weak self] moveType, affectedCubies in
            self?.animateMove(moveType, affectedCubies: affectedCubies) {}
        }

        // Bind animation state
        $isAnimating
            .sink { [weak model] animating in
                model?.isAnimating = animating
            }
            .store(in: &cancellables)
    }

    /// Rebuilds just the visual materials (after logical move without animation)
    func rebuildCubeMaterials() {
        guard let cube = cube else { return }

        for cubie in cube.cubies {
            if let node = cubie.node {
                renderer.updateCubieNode(node, for: cubie)
                // Update position
                let offset: Float = 1.0
                node.position = SCNVector3(
                    Float(cubie.x) - offset,
                    Float(cubie.y) - offset,
                    Float(cubie.z) - offset
                )
                // Update node name to match new position (important for gesture detection)
                node.name = "cubie_\(cubie.x)_\(cubie.y)_\(cubie.z)"
                // Reset any accumulated rotation on the node (use valid axis with 0 angle)
                node.rotation = SCNVector4(0, 1, 0, 0)
            }
        }
    }

    /// Animates a cube move with pre-computed affected cubies
    func animateMove(_ moveType: MoveType, affectedCubies: [Cubie], completion: @escaping () -> Void) {
        guard let cube = cube else {
            completion()
            return
        }

        guard !isAnimating else {
            completion()
            return
        }

        isAnimating = true

        // Use the pre-computed affected cubies (from before position update)
        let affectedNodes = affectedCubies.compactMap { $0.node }

        guard !affectedNodes.isEmpty else {
            // Still apply model update even if no nodes
            cube.applyMoveToModel(moveType: moveType, affectedCubies: affectedCubies)
            isAnimating = false
            completion()
            return
        }

        // Create pivot node at center
        let pivotNode = SCNNode()
        pivotNode.name = "pivot"
        pivotNode.position = SCNVector3(0, 0, 0)
        cubeRootNode.addChildNode(pivotNode)

        // Reparent affected nodes to pivot
        for node in affectedNodes {
            let worldPos = node.worldPosition
            node.removeFromParentNode()
            pivotNode.addChildNode(node)
            node.worldPosition = worldPos
        }

        // Calculate rotation
        let angle = moveType.angle
        var rotationAxis: SCNVector3

        switch moveType.axis {
        case .x:
            rotationAxis = SCNVector3(1, 0, 0)
        case .y:
            rotationAxis = SCNVector3(0, 1, 0)
        case .z:
            rotationAxis = SCNVector3(0, 0, 1)
        }

        // Create animation
        let rotation = SCNAction.rotate(by: CGFloat(angle), around: rotationAxis, duration: animationDuration)
        rotation.timingMode = .easeInEaseOut

        // Execute animation
        pivotNode.runAction(rotation) { [weak self] in
            DispatchQueue.main.async {
                // Always reset isAnimating, even if self or cube is nil
                defer {
                    self?.isAnimating = false
                    completion()
                }

                guard let self = self, let cube = self.cube else { return }

                // Reparent nodes back to cube root
                for node in affectedNodes {
                    let worldPos = node.worldPosition
                    let worldTransform = node.worldTransform
                    node.removeFromParentNode()
                    self.cubeRootNode.addChildNode(node)
                    node.worldPosition = worldPos
                    node.transform = self.cubeRootNode.convertTransform(worldTransform, from: nil)
                }

                // Remove pivot
                pivotNode.removeFromParentNode()

                // NOW apply the model update after animation completes
                cube.applyMoveToModel(moveType: moveType, affectedCubies: affectedCubies)

                // Rebuild to clean up floating point errors and update node positions/names
                self.rebuildCubeMaterials()
            }
        }
    }

    /// Rotates the entire cube by the given angles
    func rotateCube(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.01

        // Convert deltas to rotation
        let rotationX = Quaternion(axis: SCNVector3(1, 0, 0), angle: deltaY * sensitivity)
        let rotationY = Quaternion(axis: SCNVector3(0, 1, 0), angle: deltaX * sensitivity)

        // Apply rotations
        let currentQuat = cubeRootNode.rotationQuaternion
        let newQuat = (rotationY * rotationX * currentQuat).normalized

        cubeRootNode.setRotation(from: newQuat)
    }

    /// Adds rotation to the cube
    func addRotation(angle: Float, axis: SCNVector3) {
        let rotationQuat = Quaternion(axis: axis, angle: angle)
        let currentQuat = cubeRootNode.rotationQuaternion
        let newQuat = (rotationQuat * currentQuat).normalized
        cubeRootNode.setRotation(from: newQuat)
    }

    /// Sets the camera distance (zoom)
    func setCameraDistance(_ distance: Float) {
        let clampedDistance = distance.clamped(to: minCameraDistance...maxCameraDistance)
        cameraNode?.position.z = clampedDistance
    }

    /// Gets the current camera distance
    var cameraDistance: Float {
        return cameraNode?.position.z ?? defaultCameraDistance
    }

    /// Resets the camera to default position
    func resetCamera() {
        cameraNode?.position = SCNVector3(0, 0, defaultCameraDistance)

        // Reset cube rotation
        let initialRotation = Quaternion(axis: SCNVector3(1, 0, 0), angle: 0.3)
        let secondRotation = Quaternion(axis: SCNVector3(0, 1, 0), angle: -0.5)
        let combined = secondRotation * initialRotation
        cubeRootNode.rotation = combined.toAxisAngle()
    }

    /// Returns the cubie at a hit test result
    func getCubie(at hitResult: SCNHitTestResult) -> Cubie? {
        guard let cube = cube else { return nil }

        var node = hitResult.node
        while let parent = node.parent {
            if let name = node.name, name.starts(with: "cubie_") {
                // Parse position from name
                let components = name.replacingOccurrences(of: "cubie_", with: "").split(separator: "_")
                if components.count == 3,
                   let x = Int(components[0]),
                   let y = Int(components[1]),
                   let z = Int(components[2]) {
                    return cube.getCubie(at: x, y, z)
                }
            }
            node = parent
        }
        return nil
    }

    /// Returns the face that was hit
    func getHitFace(at hitResult: SCNHitTestResult) -> CubeFace? {
        let normal = hitResult.localNormal

        // Determine which face based on normal direction
        let absX = abs(normal.x)
        let absY = abs(normal.y)
        let absZ = abs(normal.z)

        if absX >= absY && absX >= absZ {
            return normal.x > 0 ? .right : .left
        } else if absY >= absX && absY >= absZ {
            return normal.y > 0 ? .up : .down
        } else {
            return normal.z > 0 ? .front : .back
        }
    }
}
