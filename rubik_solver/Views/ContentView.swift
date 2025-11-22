//
//  ContentView.swift
//  rubik_solver
//
//  Main view for the Rubik's Cube app with UI controls
//

import SwiftUI

/// Main content view with cube and controls
struct ContentView: View {
    @StateObject private var cube = RubiksCube()
    @StateObject private var sceneController = CubeSceneController()
    @State private var showCongratulations = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.15, green: 0.15, blue: 0.2)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // 3D Cube View
                RubiksCubeSceneView(cube: cube, sceneController: sceneController)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Status indicators
                statusView

                // Control buttons
                controlButtonsView

                // Instructions
                instructionsView
            }
        }
        .onChange(of: cube.isSolved) { newValue in
            if newValue && cube.moveCount > 0 {
                showCongratulations = true
            }
        }
        .alert("Gratulacje!", isPresented: $showCongratulations) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Udalo Ci sie ulozyc kostke Rubika w \(cube.moveCount) ruchach!")
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Kostka Rubika 3D")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            // Move counter badge
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                Text("\(cube.moveCount)")
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }

    // MARK: - Status View

    private var statusView: some View {
        HStack(spacing: 20) {
            // Solved status
            HStack(spacing: 6) {
                Circle()
                    .fill(cube.isSolved ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(cube.isSolved ? "Ulozona" : "Pomieszana")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Animation status
            if sceneController.isAnimating {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                    Text("Animacja...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Control Buttons View

    private var controlButtonsView: some View {
        HStack(spacing: 12) {
            // Scramble button
            ControlButton(
                title: "Pomieszaj",
                systemImage: "shuffle",
                color: .blue
            ) {
                scrambleCube()
            }
            .disabled(sceneController.isAnimating)

            // Reset button
            ControlButton(
                title: "Reset",
                systemImage: "arrow.counterclockwise",
                color: .red
            ) {
                resetCube()
            }
            .disabled(sceneController.isAnimating)

            // Undo button
            ControlButton(
                title: "Cofnij",
                systemImage: "arrow.uturn.backward",
                color: .orange
            ) {
                undoMove()
            }
            .disabled(cube.moveHistory.isEmpty || sceneController.isAnimating)

            // Reset view button
            ControlButton(
                title: "Widok",
                systemImage: "camera.viewfinder",
                color: .purple
            ) {
                resetView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        VStack(spacing: 4) {
            Text("Przeciagnij aby obrocic kostke")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Text("Przesun (swipe) na sciance aby wykonac ruch")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Text("Uszczypnij (pinch) aby przyblizac/oddalac")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func scrambleCube() {
        cube.scramble(moves: 25)
        sceneController.rebuildCubeMaterials()
    }

    private func resetCube() {
        cube.reset()
        sceneController.buildCube(from: cube)
    }

    private func undoMove() {
        cube.undoLastMove()
    }

    private func resetView() {
        sceneController.resetCamera()
    }
}

// MARK: - Control Button Component

struct ControlButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
