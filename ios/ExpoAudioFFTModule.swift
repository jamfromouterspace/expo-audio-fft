import ExpoModulesCore
import UIKit
import MobileCoreServices

public class ExpoAudioFFTModule: Module {
    private var audioProcessor: AudioProcessor?
    private var shaderViewRef: ExpoMetalShaderView? = nil
    
  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.
    public func definition() -> ModuleDefinition {
        // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
        // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
        // The module will be accessible from `requireNativeModule('ExpoAudioFFT')` in JavaScript.
        Name("ExpoAudioFFT")
        
        // Sets constant properties on the module. Can take a dictionary or a closure that returns a dictionary.
        Constants([
            "PI": Double.pi
        ])
        
        // Defines event names that the module can send to JavaScript.
        Events("onAudioBuffer", "onProgress")
        
        // Defines a JavaScript synchronous function that runs the native code on the JavaScript thread.
        Function("hello") {
            return "Hello world 👋"
        }
        
        AsyncFunction("init") { disableFFT in
            audioProcessor = try AudioProcessor(onData: { rawMagnitudes, bandMagnitudes, bandFrequencies, loudness, currentTime in
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        if self?.shaderViewRef != nil {
                            var spectrum = FixedArray64<Float>(repeating: 0.0)
                            for (index, value) in bandFrequencies.enumerated() {
                                if index < 64 {
                                    spectrum[index] = value
                                }
                            }
                        }
                    }

                self.sendEvent("onAudioBuffer", [
                    "rawMagnitudes": rawMagnitudes,
                    "bandMagnitudes": bandMagnitudes,
                    "bandFrequencies": bandFrequencies,
                    "loudness": loudness,
                    "currentTime": currentTime
                ])
                self.sendEvent("onProgress", [
                    "currentTime": currentTime
                ])
            })
            if disableFFT {
                audioProcessor!.enableFFT = false
            }
        }
        
        Function("currentTime") {
            return audioProcessor?.currentTime
        }
        
        AsyncFunction("load") { localUri in
            try audioProcessor?.load(localUri: localUri)
        }
        
        AsyncFunction("setBandingOptions") { numBands, bandingMethod in
            audioProcessor?.setBandingOptions(numBands: numBands, bandingMethod: bandingMethod)
        }
        
        AsyncFunction("getMetadata") { (localUri: String) -> [String: Any]? in
            let metadata = try AudioMetadata(localUri: localUri)
            return [
                "duration": metadata.duration,
                "sampleRate": metadata.sampleRate,
                "totalSamples": metadata.totalSamples,
                "channelCount": metadata.channelCount,
            ]
        }
        
        AsyncFunction("play") {
            try audioProcessor?.play()
        }
        
        AsyncFunction("pause") {
            try audioProcessor?.pause()
        }
        
        AsyncFunction("seek") { to in
            try audioProcessor?.seek(to: to)
        }
        
        // Enables the module to be used as a native view. Definition components that are accepted as part of the
        // view definition: Prop, Events.
        View(ExpoMetalShaderView.self) {
            // Defines a setter for the `name` prop.
            // Defines a setter for the `url` prop.
            Prop("shader") { (view: ExpoMetalShaderView, shader: String) in
                self.shaderViewRef = view
                view.updateShader(newShader: shader)
            }
            
            Prop("isPaused") { (view: ExpoMetalShaderView, isPaused: Bool) in
                view.updateIsPaused(isPaused: isPaused)
            }
            
            AsyncFunction("updateUniforms") { (view: ExpoMetalShaderView, newUniforms: [String: Any]) in
                // Convert your `[String: Any]` into a `Uniforms` struct
                do {
//                    print("new uniforms", newUniforms)
                    let uniforms = try parseUniforms(dict: newUniforms)
                    // Push to the view WITHOUT causing SwiftUI re-render (see next steps)
                    view.updateUniforms(newUniforms: uniforms)
                } catch {
                    // handle error
                    print("Failed to parse uniforms \(error)")
                }
            }
            
            Events("onError")
        }
    }
  }


// Helper for converting `[String: Any]` -> `Uniforms`
func parseUniforms(dict: [String: Any]) throws -> Uniforms {
    // Same logic you used in your Prop("uniforms") method
    let varFloat1 = try convertFloat(dict["varFloat1"])
    let varFloat2 = try convertFloat(dict["varFloat2"])
    let varFloat3 = try convertFloat(dict["varFloat3"])
    let varCumulativeFloat1 = try convertFloat(dict["varCumulativeFloat1"])
    let varCumulativeFloat2 = try convertFloat(dict["varCumulativeFloat2"])
    let varCumulativeFloat3 = try convertFloat(dict["varCumulativeFloat3"])
    
    let intensity1 = try convertFloat(dict["intensity1"])
    let intensity2 = try convertFloat(dict["intensity2"])
    let intensity3 = try convertFloat(dict["intensity3"])
    
    let cumulativeBass = try convertFloat(dict["cumulativeBass"])
    let bass = try convertFloat(dict["bass"])
    
    // Convert spectrum array
    var spectrum = FixedArray64<Float>(repeating: 0.0)
//    if let spectrumArray = dict["spectrum"] as? [Any] {
//        for (index, value) in spectrumArray.enumerated() {
//            if index < 64 {
//                spectrum[index] = try convertFloat(value)
//            }
//        }
//    }
    
    var color1 = SIMD3<Float>(repeating: 0)
    if let colorArray = dict["color1"] as? [Any] {
        for (index, value) in colorArray.enumerated() {
            if index < 3 {
                color1[index] = try convertFloat(value)
            }
        }
    }
    
    var color2 = SIMD3<Float>(repeating: 0)
    if let colorArray = dict["color2"] as? [Any] {
        for (index, value) in colorArray.enumerated() {
            if index < 3 {
                color2[index] = try convertFloat(value)
            }
        }
    }
    
    var color3 = SIMD3<Float>(repeating: 0)
    if let colorArray = dict["color3"] as? [Any] {
        for (index, value) in colorArray.enumerated() {
            if index < 3 {
                color3[index] = try convertFloat(value)
            }
        }
    }
    
    // build and return Uniforms struct
    return Uniforms(
        iTime: 0, // or whatever
        iResolution: SIMD2<Float>(
            dict["iResolutionX"] as? Float ?? 1024,
            dict["iResolutionY"] as? Float ?? 768
        ),
        varFloat1: varFloat1,
        varFloat2: varFloat2,
        varFloat3: varFloat3,
        varCumulativeFloat1: varCumulativeFloat1,
        varCumulativeFloat2: varCumulativeFloat2,
        varCumulativeFloat3: varCumulativeFloat3,

        color1: color1,
        color2: color2,
        color3: color3,
        
        intensity1: intensity1,
        intensity2: intensity2,
        intensity3: intensity3,
       
        bass: bass,
        cumulativeBass: cumulativeBass,
        
        spectrum: spectrum
    )
}

enum UniformTypeError: Error {
    case invalidFloat(inputType: Any.Type)
    case invalidInt(inputType: Any.Type)
    case invalidBool(inputType: Any.Type)
}


func convertFloat(_ inputVar: Any?) throws -> Float {
    var outputVar: Float
    if inputVar == nil {
        return 0.0
    } else if let number = inputVar as? NSNumber {
        outputVar = number.floatValue
    } else if let value = inputVar as? Float {
        outputVar = value
    } else if let value = inputVar as? Int {
        outputVar = Float(value)
    } else {
        throw UniformTypeError.invalidFloat(inputType: type(of: inputVar))
    }
    return outputVar
}

func convertInt(_ inputVar: Any?) throws -> Int {
    var outputVar: Int
    if inputVar == nil {
        return 0
    } else if let number = inputVar as? NSNumber {
        outputVar = number.intValue
    } else if let value = inputVar as? Int {
        outputVar = value
    } else if let value = inputVar as? Float {
        outputVar = Int(value)
    } else {
        throw UniformTypeError.invalidInt(inputType: type(of: inputVar))
    }
    return outputVar
}

func convertInt32(_ inputVar: Any?) throws -> Int32 {
    var outputVar: Int32
    if inputVar == nil {
        return 0
    } else if let number = inputVar as? NSNumber {
        outputVar = Int32(number.intValue)
    } else if let value = inputVar as? Int {
        outputVar = Int32(value)
    } else if let value = inputVar as? Float {
        outputVar = Int32(value)
    } else {
        throw UniformTypeError.invalidInt(inputType: type(of: inputVar))
    }
    return outputVar
}


func convertBool(_ inputVar: Any?) throws -> Bool {
    var outputVar: Bool
    if inputVar == nil {
        return false
    } else if let number = inputVar as? NSNumber {
        outputVar = number.boolValue
    } else if let value = inputVar as? Bool {
        outputVar = value
    } else if let value = inputVar as? Int {
        outputVar = value == 0 ? false : true
    } else {
        throw UniformTypeError.invalidBool(inputType: type(of: inputVar))
    }
    return outputVar
}



