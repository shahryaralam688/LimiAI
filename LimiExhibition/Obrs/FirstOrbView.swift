//
//  OrbView.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 29/11/2025.
//


import SwiftUI
import MetalKit

// MARK: - Public SwiftUI View

struct FirstOrbView: View {
    var hue: Float = 0
    var hoverIntensity: Float = 0.2
    var rotateOnHover: Bool = true
    var forceHoverState: Bool = false

    var body: some View {
        OrbMetalView(
            hue: hue,
            hoverIntensity: hoverIntensity,
            rotateOnHover: rotateOnHover,
            forceHoverState: forceHoverState
        )
        .frame(maxWidth: .infinity, maxHeight: 600)
        .background(Color.clear)
    }
}

// MARK: - MetalKit Wrapper

struct OrbMetalView: UIViewRepresentable {
    typealias UIViewType = MTKView

    var hue: Float
    var hoverIntensity: Float
    var rotateOnHover: Bool
    var forceHoverState: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hue: hue,
            hoverIntensity: hoverIntensity,
            rotateOnHover: rotateOnHover,
            forceHoverState: forceHoverState
        )
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60

        context.coordinator.setup(view: mtkView)
        mtkView.delegate = context.coordinator

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.hue = hue
        context.coordinator.hoverIntensity = hoverIntensity
        context.coordinator.rotateOnHover = rotateOnHover
        context.coordinator.forceHoverState = forceHoverState
    }

    // MARK: - Coordinator (MTKViewDelegate)

    class Coordinator: NSObject, MTKViewDelegate {
        struct Uniforms {
            var time: Float
            var resolution: SIMD3<Float>
            var hue: Float
            var hover: Float
            var rot: Float
            var hoverIntensity: Float
        }

        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!

        var startTime: CFTimeInterval = CACurrentMediaTime()
        var lastTime: CFTimeInterval = CACurrentMediaTime()
        var hoverValue: Float = 0.0
        var currentRot: Float = 0.0

        // Exposed parameters (updated from SwiftUI)
        var hue: Float
        var hoverIntensity: Float
        var rotateOnHover: Bool
        var forceHoverState: Bool

        init(hue: Float, hoverIntensity: Float, rotateOnHover: Bool, forceHoverState: Bool) {
            self.hue = hue
            self.hoverIntensity = hoverIntensity
            self.rotateOnHover = rotateOnHover
            self.forceHoverState = forceHoverState
        }

        func setup(view: MTKView) {
            guard let device = view.device else { return }
            self.device = device
            self.commandQueue = device.makeCommandQueue()

            let library = try! device.makeDefaultLibrary(bundle: .main)
            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_main")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                fatalError("Failed to create pipeline state: \(error)")
            }

            startTime = CACurrentMediaTime()
            lastTime = startTime
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Nothing special needed here; we read drawableSize in draw(in:)
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else {
                return
            }

            let now = CACurrentMediaTime()
            let dt = Float(now - lastTime)
            lastTime = now
            let t = Float(now - startTime)

            // In the JS version, hover is smoothed toward targetHover based on
            // the mouse position inside the orb. Here we approximate:
            // - if forceHoverState == true -> hover is fully active (1)
            // - otherwise -> hover is 0 (no interaction)
            let targetHover: Float = forceHoverState ? 1.0 : 0.0
            hoverValue += (targetHover - hoverValue) * 0.1

            // rotation logic (only when hover is active, like JS)
            if rotateOnHover && hoverValue > 0.5 {
                let rotationSpeed: Float = 0.3
                currentRot += dt * rotationSpeed
            }

            // Resolution: width, height, aspect
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            let aspect = width / max(height, 1.0)

            var uniforms = Uniforms(
                time: t,
                resolution: SIMD3<Float>(width, height, aspect),
                hue: hue,
                hover: hoverValue,
                rot: currentRot,
                hoverIntensity: hoverIntensity
            )

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            encoder.setRenderPipelineState(pipelineState)

            // Full-screen triangle – we generate vertices procedurally in the vertex shader,
            // so we only need the uniforms buffer here.
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

#Preview{
    FirstOrbView() 
}
