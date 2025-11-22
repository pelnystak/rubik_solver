//
//  GestureHandler.swift
//  rubik_solver
//
//  Handles gesture recognition for cube interaction
//

import UIKit
import SceneKit

/// Protocol for gesture handler delegate
protocol GestureHandlerDelegate: AnyObject {
    func gestureHandler(_ handler: GestureHandler, didRequestMove moveType: MoveType)
    func gestureHandler(_ handler: GestureHandler, didRotateCubeBy deltaX: Float, deltaY: Float)
    func gestureHandler(_ handler: GestureHandler, didZoomTo distance: Float)
}

/// Handles all gesture recognition and translation to cube moves
class GestureHandler: NSObject, UIGestureRecognizerDelegate {
    /// Delegate for gesture events
    weak var delegate: GestureHandlerDelegate?

    /// Reference to the scene controller
    weak var sceneController: CubeSceneController?

    /// Reference to the cube model
    weak var cube: RubiksCube?

    /// The SCNView for hit testing
    weak var scnView: SCNView?

    /// Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Tracking for two-finger pan (cube rotation)
    private var lastTwoFingerPanLocation: CGPoint = .zero

    /// Tracking for single finger
    private var panStartLocation: CGPoint = .zero
    private var panStartTime: Date = Date()
    private var hitCubie: Cubie?
    private var hitFace: CubeFace?
    private var isDraggingCube: Bool = false

    /// Pinch tracking
    private var initialPinchDistance: Float = 0

    /// Thresholds
    private let swipeVelocityThreshold: CGFloat = 300
    private let swipeDistanceThreshold: CGFloat = 30
    private let dragThreshold: CGFloat = 10

    override init() {
        super.init()
        feedbackGenerator.prepare()
    }

    /// Configures gesture recognizers on the view
    func setupGestures(on view: UIView) {
        // Single finger pan - for layer moves or cube rotation
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)

        // Two finger pan - for cube rotation
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(twoFingerPan)

        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Double tap for reset view
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }

    /// Handles single finger pan
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let scnView = scnView,
              let sceneController = sceneController else { return }

        switch gesture.state {
        case .began:
            panStartLocation = gesture.location(in: scnView)
            panStartTime = Date()
            isDraggingCube = false

            // Hit test to see if we touched a cubie
            let hitResults = scnView.hitTest(panStartLocation, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])

            if let hitResult = hitResults.first {
                hitCubie = findCubieFromNode(hitResult.node)
                hitFace = sceneController.getHitFace(at: hitResult)
            } else {
                hitCubie = nil
                hitFace = nil
                isDraggingCube = true
            }

        case .changed:
            let currentLocation = gesture.location(in: scnView)
            let deltaX = currentLocation.x - panStartLocation.x
            let deltaY = currentLocation.y - panStartLocation.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

            // If we haven't hit a cubie, rotate the whole cube
            if hitCubie == nil || isDraggingCube {
                if distance > dragThreshold {
                    isDraggingCube = true
                    let velocity = gesture.velocity(in: scnView)
                    delegate?.gestureHandler(self, didRotateCubeBy: Float(velocity.x) * 0.1, deltaY: Float(velocity.y) * 0.1)
                }
            }

        case .ended, .cancelled:
            let currentLocation = gesture.location(in: scnView)
            let velocity = gesture.velocity(in: scnView)
            let deltaX = currentLocation.x - panStartLocation.x
            let deltaY = currentLocation.y - panStartLocation.y

            // Check if this was a swipe on a cubie
            if let cubie = hitCubie, let face = hitFace, !isDraggingCube {
                let absVelX = abs(velocity.x)
                let absVelY = abs(velocity.y)

                // Determine swipe direction
                var direction: SwipeDirection?
                if absVelX > swipeVelocityThreshold || absVelY > swipeVelocityThreshold {
                    if absVelX > absVelY {
                        direction = velocity.x > 0 ? .right : .left
                    } else {
                        direction = velocity.y > 0 ? .down : .up
                    }
                } else if abs(deltaX) > swipeDistanceThreshold || abs(deltaY) > swipeDistanceThreshold {
                    if abs(deltaX) > abs(deltaY) {
                        direction = deltaX > 0 ? .right : .left
                    } else {
                        direction = deltaY > 0 ? .down : .up
                    }
                }

                if let dir = direction,
                   let moveType = determineMoveType(cubie: cubie, face: face, direction: dir) {
                    feedbackGenerator.impactOccurred()
                    delegate?.gestureHandler(self, didRequestMove: moveType)
                }
            }

            // Reset state
            hitCubie = nil
            hitFace = nil
            isDraggingCube = false

        default:
            break
        }
    }

    /// Handles two finger pan for cube rotation
    @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }

        switch gesture.state {
        case .began:
            lastTwoFingerPanLocation = gesture.location(in: view)

        case .changed:
            let currentLocation = gesture.location(in: view)
            let deltaX = Float(currentLocation.x - lastTwoFingerPanLocation.x)
            let deltaY = Float(currentLocation.y - lastTwoFingerPanLocation.y)

            delegate?.gestureHandler(self, didRotateCubeBy: deltaX, deltaY: deltaY)
            lastTwoFingerPanLocation = currentLocation

        default:
            break
        }
    }

    /// Handles pinch gesture for zoom
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let sceneController = sceneController else { return }

        switch gesture.state {
        case .began:
            initialPinchDistance = sceneController.cameraDistance

        case .changed:
            let scale = Float(gesture.scale)
            let newDistance = initialPinchDistance / scale
            delegate?.gestureHandler(self, didZoomTo: newDistance)

        default:
            break
        }
    }

    /// Handles double tap for reset view
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        sceneController?.resetCamera()
    }

    /// Find cubie from hit node by traversing up to find cubie node
    private func findCubieFromNode(_ node: SCNNode) -> Cubie? {
        var currentNode: SCNNode? = node

        while let n = currentNode {
            if let name = n.name, name.starts(with: "cubie_") {
                // Find the cubie that has this node as its reference
                if let cube = cube {
                    for cubie in cube.cubies {
                        if cubie.node === n {
                            return cubie
                        }
                    }
                }
            }
            currentNode = n.parent
        }
        return nil
    }

    /// Swipe direction enum
    private enum SwipeDirection {
        case up, down, left, right
    }

    /// Determines the move type based on cubie, face, and swipe direction
    private func determineMoveType(cubie: Cubie, face: CubeFace, direction: SwipeDirection) -> MoveType? {
        switch face {
        case .front:
            return determineMoveForFrontFace(cubie: cubie, direction: direction)
        case .back:
            return determineMoveForBackFace(cubie: cubie, direction: direction)
        case .up:
            return determineMoveForUpFace(cubie: cubie, direction: direction)
        case .down:
            return determineMoveForDownFace(cubie: cubie, direction: direction)
        case .right:
            return determineMoveForRightFace(cubie: cubie, direction: direction)
        case .left:
            return determineMoveForLeftFace(cubie: cubie, direction: direction)
        }
    }

    private func determineMoveForFrontFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.x == 0 { return .L }
            if cubie.x == 2 { return .RPrime }
            return nil
        case .down:
            if cubie.x == 0 { return .LPrime }
            if cubie.x == 2 { return .R }
            return nil
        case .left:
            if cubie.y == 0 { return .D }
            if cubie.y == 2 { return .UPrime }
            return nil
        case .right:
            if cubie.y == 0 { return .DPrime }
            if cubie.y == 2 { return .U }
            return nil
        }
    }

    private func determineMoveForBackFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.x == 0 { return .LPrime }
            if cubie.x == 2 { return .R }
            return nil
        case .down:
            if cubie.x == 0 { return .L }
            if cubie.x == 2 { return .RPrime }
            return nil
        case .left:
            if cubie.y == 0 { return .DPrime }
            if cubie.y == 2 { return .U }
            return nil
        case .right:
            if cubie.y == 0 { return .D }
            if cubie.y == 2 { return .UPrime }
            return nil
        }
    }

    private func determineMoveForUpFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        case .down:
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        case .left:
            if cubie.x == 0 { return .L }
            if cubie.x == 2 { return .RPrime }
            return nil
        case .right:
            if cubie.x == 0 { return .LPrime }
            if cubie.x == 2 { return .R }
            return nil
        }
    }

    private func determineMoveForDownFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        case .down:
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        case .left:
            if cubie.x == 0 { return .LPrime }
            if cubie.x == 2 { return .R }
            return nil
        case .right:
            if cubie.x == 0 { return .L }
            if cubie.x == 2 { return .RPrime }
            return nil
        }
    }

    private func determineMoveForRightFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        case .down:
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        case .left:
            if cubie.y == 0 { return .D }
            if cubie.y == 2 { return .UPrime }
            return nil
        case .right:
            if cubie.y == 0 { return .DPrime }
            if cubie.y == 2 { return .U }
            return nil
        }
    }

    private func determineMoveForLeftFace(cubie: Cubie, direction: SwipeDirection) -> MoveType? {
        switch direction {
        case .up:
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        case .down:
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        case .left:
            if cubie.y == 0 { return .DPrime }
            if cubie.y == 2 { return .U }
            return nil
        case .right:
            if cubie.y == 0 { return .D }
            if cubie.y == 2 { return .UPrime }
            return nil
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pinch and pan to work together
        if gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }
}
