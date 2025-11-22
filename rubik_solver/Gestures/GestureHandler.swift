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
    func gestureHandlerDidTap(_ handler: GestureHandler, at point: CGPoint)
}

/// Handles all gesture recognition and translation to cube moves
class GestureHandler: NSObject {
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

    /// Swipe threshold
    private let swipeThreshold: CGFloat = 50

    /// Pan tracking
    private var lastPanLocation: CGPoint = .zero
    private var isPanning: Bool = false

    /// Pinch tracking
    private var initialPinchDistance: Float = 0

    override init() {
        super.init()
        feedbackGenerator.prepare()
    }

    /// Configures gesture recognizers on the view
    func setupGestures(on view: UIView) {
        // Pan gesture for rotating the cube
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGesture)

        // Swipe gestures for face moves
        for direction in [UISwipeGestureRecognizer.Direction.up, .down, .left, .right] {
            let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipeGesture.direction = direction
            swipeGesture.numberOfTouchesRequired = 1
            view.addGestureRecognizer(swipeGesture)
        }

        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)

        // Double tap for reset view
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)

        // Make single tap wait for double tap to fail
        tapGesture.require(toFail: doubleTapGesture)
    }

    /// Handles pan gesture for rotating the cube
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let sceneController = sceneController, !sceneController.isAnimating else { return }

        switch gesture.state {
        case .began:
            lastPanLocation = gesture.location(in: gesture.view)
            isPanning = true

        case .changed:
            let currentLocation = gesture.location(in: gesture.view)
            let deltaX = Float(currentLocation.x - lastPanLocation.x)
            let deltaY = Float(currentLocation.y - lastPanLocation.y)

            delegate?.gestureHandler(self, didRotateCubeBy: deltaX, deltaY: deltaY)
            lastPanLocation = currentLocation

        case .ended, .cancelled:
            isPanning = false

        default:
            break
        }
    }

    /// Handles swipe gesture for face moves
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard let scnView = scnView,
              let sceneController = sceneController,
              let cube = cube,
              !sceneController.isAnimating else { return }

        let location = gesture.location(in: scnView)

        // Perform hit test
        let hitResults = scnView.hitTest(location, options: [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .ignoreHiddenNodes: true
        ])

        guard let hitResult = hitResults.first,
              let cubie = sceneController.getCubie(at: hitResult),
              let hitFace = sceneController.getHitFace(at: hitResult) else {
            return
        }

        // Determine move based on cubie position, face hit, and swipe direction
        if let moveType = determineMoveType(cubie: cubie, face: hitFace, direction: gesture.direction) {
            // Provide haptic feedback
            feedbackGenerator.impactOccurred()

            delegate?.gestureHandler(self, didRequestMove: moveType)
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

    /// Handles tap gesture
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: gesture.view)
        delegate?.gestureHandlerDidTap(self, at: location)
    }

    /// Handles double tap for reset view
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        sceneController?.resetCamera()
    }

    /// Determines the move type based on cubie, face, and swipe direction
    private func determineMoveType(cubie: Cubie, face: CubeFace, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
        // Logic to determine which layer to rotate based on:
        // 1. Which face was tapped
        // 2. Position of the cubie on that face
        // 3. Direction of the swipe

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

    private func determineMoveForFrontFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
        default:
            return nil
        }
    }

    private func determineMoveForBackFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
        default:
            return nil
        }
    }

    private func determineMoveForUpFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        case .right:
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        default:
            return nil
        }
    }

    private func determineMoveForDownFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
            if cubie.z == 0 { return .B }
            if cubie.z == 2 { return .FPrime }
            return nil
        case .right:
            if cubie.z == 0 { return .BPrime }
            if cubie.z == 2 { return .F }
            return nil
        default:
            return nil
        }
    }

    private func determineMoveForRightFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
        default:
            return nil
        }
    }

    private func determineMoveForLeftFace(cubie: Cubie, direction: UISwipeGestureRecognizer.Direction) -> MoveType? {
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
        default:
            return nil
        }
    }
}
