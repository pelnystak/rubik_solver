//
//  CubeRenderer.swift
//  rubik_solver
//
//  Renders the 3D Rubik's Cube using SceneKit with PBR materials
//

import SceneKit
import UIKit

/// Responsible for rendering the 3D Rubik's Cube
class CubeRenderer {
    /// Size of each cubie
    let cubieSize: CGFloat = 0.95

    /// Gap between cubies
    let cubieGap: CGFloat = 0.05

    /// Corner radius for cubies
    let cornerRadius: CGFloat = 0.08

    /// Creates a cubie node for the given cubie model
    func createCubieNode(for cubie: Cubie) -> SCNNode {
        let geometry = createCubieGeometry()
        let materials = createMaterials(for: cubie)
        geometry.materials = materials

        let node = SCNNode(geometry: geometry)
        node.name = "cubie_\(cubie.x)_\(cubie.y)_\(cubie.z)"

        // Position the cubie
        let offset: Float = 1.0 // Offset to center the cube at origin
        node.position = SCNVector3(
            Float(cubie.x) - offset,
            Float(cubie.y) - offset,
            Float(cubie.z) - offset
        )

        // Store reference to cubie
        cubie.node = node

        return node
    }

    /// Creates the geometry for a single cubie
    func createCubieGeometry() -> SCNGeometry {
        let box = SCNBox(
            width: cubieSize,
            height: cubieSize,
            length: cubieSize,
            chamferRadius: cornerRadius
        )
        box.chamferSegmentCount = 3
        return box
    }

    /// Creates materials for all 6 faces of a cubie
    /// Order: right (+X), left (-X), up (+Y), down (-Y), front (+Z), back (-Z)
    func createMaterials(for cubie: Cubie) -> [SCNMaterial] {
        // SCNBox face order: +X, -X, +Y, -Y, +Z, -Z
        // Our CubeFace order: up, down, front, back, right, left
        let faceOrder: [CubeFace] = [.right, .left, .up, .down, .front, .back]

        return faceOrder.map { face in
            let color = cubie.getColor(for: face)
            return createMaterial(for: color)
        }
    }

    /// Creates a PBR material for a cube color
    func createMaterial(for color: CubeColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color.uiColor
        material.roughness.contents = 0.35
        material.metalness.contents = 0.0

        // Add slight glossiness to colored faces
        if color != .black {
            material.roughness.contents = 0.25
            material.clearCoat.contents = 0.1
            material.clearCoatRoughness.contents = 0.1
        }

        material.locksAmbientWithDiffuse = true
        return material
    }

    /// Sets up the lighting for the scene
    func setupLighting(scene: SCNScene) {
        // Main directional light (sun)
        let mainLight = SCNLight()
        mainLight.type = .directional
        mainLight.color = UIColor.white
        mainLight.intensity = 1000
        mainLight.castsShadow = true
        mainLight.shadowMode = .deferred
        mainLight.shadowSampleCount = 16
        mainLight.shadowRadius = 3
        mainLight.shadowColor = UIColor(white: 0, alpha: 0.5)

        let mainLightNode = SCNNode()
        mainLightNode.light = mainLight
        mainLightNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        mainLightNode.name = "mainLight"
        scene.rootNode.addChildNode(mainLightNode)

        // Fill light (softer, from opposite side)
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = UIColor(white: 0.9, alpha: 1.0)
        fillLight.intensity = 400

        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-5, 3, -5)
        fillLightNode.name = "fillLight"
        scene.rootNode.addChildNode(fillLightNode)

        // Rim light (back lighting for depth)
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.color = UIColor(white: 0.8, alpha: 1.0)
        rimLight.intensity = 300

        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(0, -5, -8)
        rimLightNode.name = "rimLight"
        scene.rootNode.addChildNode(rimLightNode)

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.3, alpha: 1.0)
        ambientLight.intensity = 200

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        ambientNode.name = "ambientLight"
        scene.rootNode.addChildNode(ambientNode)
    }

    /// Sets up the camera for the scene
    func setupCamera(scene: SCNScene) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100
        camera.wantsHDR = true
        camera.bloomIntensity = 0.3
        camera.bloomBlurRadius = 5

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 10)
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        return cameraNode
    }

    /// Creates a floor/ground plane with reflection
    func createFloor() -> SCNNode {
        let floor = SCNFloor()
        floor.reflectivity = 0.15
        floor.reflectionFalloffEnd = 3

        let floorMaterial = SCNMaterial()
        floorMaterial.lightingModel = .physicallyBased
        floorMaterial.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        floorMaterial.roughness.contents = 0.8
        floor.materials = [floorMaterial]

        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -3, 0)
        floorNode.name = "floor"

        return floorNode
    }

    /// Updates the materials of a cubie node
    func updateCubieNode(_ node: SCNNode, for cubie: Cubie) {
        guard let geometry = node.geometry as? SCNBox else { return }
        geometry.materials = createMaterials(for: cubie)
    }

    /// Creates the scene background
    func setupBackground(scene: SCNScene) {
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 512, height: 512)

        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
        }
        let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        scene.background.contents = backgroundImage
    }
}
