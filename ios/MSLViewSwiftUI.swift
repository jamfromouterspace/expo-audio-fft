import SwiftUI
import MetalKit

/// Shadertoy-style view. Specify a fragment shader (must be named "mainImage") and a struct of constants
/// to pass to the shader. In order to ensure the constants struct is consistent with the MSL version, it's
/// best to include it in a Swift briding header. Constants are bound at position 0, and a uint2 for the view size
/// is bound at position 1.
public struct MSLViewSwiftUI<T> : UIViewRepresentable {

    var shader: String
    var uniforms: T
    var onError: (([String: Any]) -> Void)?

    public init(shader: String, uniforms: T, onError: (([String: Any]) -> Void)?) {
        self.shader = shader
        self.uniforms = uniforms
        self.onError = onError
    }

    public class Coordinator {
        var renderer: Renderer<T>

        init(uniforms: T) {
            renderer = Renderer<T>(device: MTLCreateSystemDefaultDevice()!, uniforms: uniforms)
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(uniforms: uniforms)
    }

    public func makeUIView(context: Context) -> some UIView {
        let metalView = MTKView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                                device: MTLCreateSystemDefaultDevice()!)
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = true
        metalView.delegate = context.coordinator.renderer
        metalView.backgroundColor = UIColor.clear
        context.coordinator.renderer.onError = onError
        context.coordinator.renderer.setShader(source: shader)
        return metalView
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        context.coordinator.renderer.onError = onError
        context.coordinator.renderer.setShader(source: shader)
        context.coordinator.renderer.uniforms = uniforms
        uiView.setNeedsDisplay()
    }
}
