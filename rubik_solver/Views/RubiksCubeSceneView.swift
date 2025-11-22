//
//  RubiksCubeSceneView.swift
//  rubik_solver
//
//  UIViewRepresentable wrapper for SceneKit view
//

import SwiftUI
import SceneKit

/// SwiftUI wrapper for the SceneKit cube view
struct RubiksCubeSceneView: UIViewRepresentable {
    @ObservedObject var cube: RubiksCube
    @ObservedObject var sceneController: CubeSceneController

    /// Coordinator for handling UIKit interactions
    class Coordinator: NSObject, GestureHandlerDelegate {
        var parent: RubiksCubeSceneView
        let gestureHandler: GestureHandler

        init(_ parent: RubiksCubeSceneView) {
            self.parent = parent
            self.gestureHandler = GestureHandler()
            super.init()
            self.gestureHandler.delegate = self
        }

        // MARK: - GestureHandlerDelegate

        func gestureHandler(_ handler: GestureHandler, didRequestMove moveType: MoveType) {
            guard !parent.sceneController.isAnimating else { return }
            parent.cube.performMove(moveType)
        }

        func gestureHandler(_ handler: GestureHandler, didRotateCubeBy deltaX: Float, deltaY: Float) {
            parent.sceneController.rotateCube(deltaX: deltaX, deltaY: deltaY)
        }

        func gestureHandler(_ handler: GestureHandler, didZoomTo distance: Float) {
            parent.sceneController.setCameraDistance(distance)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneController.scene
        scnView.backgroundColor = .clear

        // Rendering options
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false

        // Performance options
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = false

        // Setup gesture handler
        context.coordinator.gestureHandler.scnView = scnView
        context.coordinator.gestureHandler.sceneController = sceneController
        context.coordinator.gestureHandler.cube = cube
        context.coordinator.gestureHandler.setupGestures(on: scnView)

        // Build the cube
        sceneController.buildCube(from: cube)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update coordinator references if needed
        context.coordinator.gestureHandler.cube = cube
        context.coordinator.parent = self
    }
}
