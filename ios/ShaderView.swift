import SwiftUI

struct ShaderView: View {
    @ObservedObject var model: UniformsModel

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        MSLViewSwiftUI(shader: model.shader, uniforms: model.uniforms, onError: model.onError)
            .onReceive(timer) { time in
                if model.isPaused {
                    return
                }
                model.uniforms.iTime += 1/60
                model.uniforms.iResolution = model.pendingUniforms.iResolution
                
                model.uniforms.varFloat1 = model.pendingUniforms.varFloat1
                model.uniforms.varFloat2 = model.pendingUniforms.varFloat2
                model.uniforms.varFloat3 = model.pendingUniforms.varFloat3
                
                model.uniforms.varCumulativeFloat1 += model.pendingUniforms.varCumulativeFloat1
                model.uniforms.varCumulativeFloat2 += model.pendingUniforms.varCumulativeFloat2
                model.uniforms.varCumulativeFloat3 += model.pendingUniforms.varCumulativeFloat3
                
                model.uniforms.color1 = model.pendingUniforms.color1
                model.uniforms.color2 = model.pendingUniforms.color2
                model.uniforms.color3 = model.pendingUniforms.color3
                              
                model.uniforms.intensity1 = model.pendingUniforms.intensity1
                model.uniforms.intensity2 = model.pendingUniforms.intensity2
                model.uniforms.intensity3 = model.pendingUniforms.intensity3

                model.uniforms.moveToMusic = model.pendingUniforms.moveToMusic
                
                model.uniforms.spectrum = model.spectrum
                
                // Average the first 4 bands of the spectrum for a punchy bass value
                let bassRange = 14 // First 4 bands contain sub-bass and bass frequencies
                var bassSum: Float = 0
                for i in 0..<bassRange {
                    bassSum += model.spectrum[i]
                }
                model.uniforms.bass = bassSum / Float(bassRange)
                model.uniforms.cumulativeBass += model.uniforms.bass
                
            }
            .edgesIgnoringSafeArea(.all)
    }
    
}
