import ExpoModulesCore
import SwiftUI
import UIKit

import SwiftUI
import simd

let DEFAULT_SHADER = """
    fragment float4 mainImage() {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
"""

struct FixedArray64<T> {
    var elements: (T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T,
                  T, T, T, T, T, T, T, T)
    
    init(repeating value: T) {
        elements = (value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value,
                   value, value, value, value, value, value, value, value)
    }
    
    subscript(index: Int) -> T {
        get {
            precondition(index >= 0 && index < 64, "Index out of range")
            return withUnsafeBytes(of: elements) { ptr in
                ptr.load(fromByteOffset: index * MemoryLayout<T>.stride, as: T.self)
            }
        }
        set {
            precondition(index >= 0 && index < 64, "Index out of range")
            withUnsafeMutableBytes(of: &elements) { ptr in
                ptr.storeBytes(of: newValue, toByteOffset: index * MemoryLayout<T>.stride, as: T.self)
            }
        }
    }
}

struct Uniforms {
    var iTime: Float
    var iResolution: SIMD2<Float>
    var varFloat1: Float
    var varFloat2: Float
    var varFloat3: Float
    var varCumulativeFloat1: Float
    var varCumulativeFloat2: Float
    var varCumulativeFloat3: Float
    
    var color1: SIMD3<Float>
    var color2: SIMD3<Float>
    var color3: SIMD3<Float>
    
    var intensity1: Float
    var intensity2: Float
    var intensity3: Float
    var bass: Float
    var cumulativeBass: Float
    var moveToMusic: Float
    
    var spectrum: FixedArray64<Float>
    
}

class UniformsModel: ObservableObject {
  // The uniforms actually used by the shader (causes SwiftUI updates)
  @Published var uniforms: Uniforms
  
  // A non-published copy that won’t trigger any view updates
  var pendingUniforms: Uniforms
  
  @Published var shader: String
    
  @Published var isPaused: Bool
    
  @Published var onError: (([String : Any]) -> Void)? = nil
    
  var spectrum = FixedArray64<Float>(repeating: 0.0)
  
  init() {
    let defaultUniforms = Uniforms(
      iTime: 0.0,
      iResolution: SIMD2<Float>(1024, 768),
      varFloat1: 0.0,
      varFloat2: 0.0,
      varFloat3: 0.0,
      varCumulativeFloat1: 0.0,
      varCumulativeFloat2: 0.0,
      varCumulativeFloat3: 0.0,
      color1: SIMD3<Float>(repeating: 0.0),
      color2: SIMD3<Float>(repeating: 0.0),
      color3: SIMD3<Float>(repeating: 0.0),
      intensity1: 0,
      intensity2: 0,
      intensity3: 0,
      
      bass: 0,
      cumulativeBass: 0,
      moveToMusic: 1.0,
      
      spectrum: FixedArray64<Float>(repeating: 0.0)
    )
    
    self.uniforms = defaultUniforms
    self.pendingUniforms = defaultUniforms
    self.shader = DEFAULT_SHADER
    self.isPaused = false
  }
}

class ExpoMetalShaderView: ExpoView {
    let onError = EventDispatcher()
    
    private let contentView: UIHostingController<ShaderView>
    
    private let uniformsModel = UniformsModel()
    
    required init(appContext: AppContext? = nil) {
        contentView = UIHostingController(rootView: ShaderView(model: uniformsModel))
        contentView.view.backgroundColor = UIColor.clear
        super.init(appContext: appContext)
        
        uniformsModel.onError = { errorDict in
            self.onError(errorDict)
        }
    
        // clipsToBounds = true
        addSubview(contentView.view)
    }
    
    override func layoutSubviews() {
        contentView.view.frame = bounds
    }
    
    func updateUniforms(newUniforms: Uniforms) {
        DispatchQueue.main.async {
            self.uniformsModel.pendingUniforms = newUniforms
        }
    }
    
    func updateShader(newShader: String) {
        DispatchQueue.main.async {
            self.uniformsModel.shader = newShader
        }
    }
    
    func updateIsPaused(isPaused: Bool) {
        DispatchQueue.main.async {
            self.uniformsModel.isPaused = isPaused
        }
    }
    
    func updateSpectrum(spectrum: FixedArray64<Float>) {
        DispatchQueue.main.async {
            self.uniformsModel.spectrum = spectrum
        }
    }
}
