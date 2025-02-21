import UIKit
import MetalKit

/// Shadertoy-style view using UIKit. Specify a fragment shader (must be named "mainImage") and a struct of constants
/// to pass to the shader. Constants are bound at position 0, and a uint2 for the view size is bound at position 1.
public class MSLView<T>: UIView {
    
    var shader: String
    var uniforms: T
    private var renderer: Renderer<T>
    private var metalView: MTKView!
    
    public init(frame: CGRect, shader: String, uniforms: T) {
        self.shader = shader
        self.uniforms = uniforms
        self.renderer = Renderer<T>(device: MTLCreateSystemDefaultDevice()!, uniforms: uniforms)
        
        super.init(frame: frame)
        
        setupMetalView()
        configureRenderer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMetalView() {
        metalView = MTKView(frame: self.bounds, device: MTLCreateSystemDefaultDevice())
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false
        metalView.delegate = renderer
        addSubview(metalView)
    }
    
    private func configureRenderer() {
        renderer.setShader(source: shader)
    }
    
    /// Update the shader and constants, then refresh the view.
    public func update(shader: String, uniforms: T) {
        self.shader = shader
        self.uniforms = uniforms
        renderer.setShader(source: shader)
        renderer.uniforms = uniforms
        metalView.setNeedsDisplay()
    }

    public func updateShader(shader: String) {
        self.shader = shader
        renderer.setShader(source: shader)
        metalView.setNeedsDisplay()
    }
    
    public func updateUniforms(uniforms: T) {
        self.uniforms = uniforms
        renderer.uniforms = uniforms
        print("uniforms", uniforms)
        metalView.setNeedsDisplay()
    }

    public func setIsPaused(_ isPaused: Bool) {
        metalView.isPaused = isPaused
    }
}
