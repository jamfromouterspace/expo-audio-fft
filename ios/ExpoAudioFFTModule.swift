import ExpoModulesCore
import UIKit
import MobileCoreServices

public class ExpoAudioFFTModule: Module {
    private var audioProcessor: AudioProcessor?
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
            audioProcessor = AudioProcessor(onData: { rawMagnitudes, bandMagnitudes, bandFrequencies, loudness, currentTime in
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
            audioProcessor?.play()
        }
        
        AsyncFunction("pause") {
            audioProcessor?.pause()
        }
        
        AsyncFunction("seek") { to in
            audioProcessor?.seek(to: to)
        }
        
        // Defines a JavaScript function that always returns a Promise and whose native code
        // is by default dispatched on the different thread than the JavaScript runtime runs on.
        //      AsyncFunction("getWaveformData") { (localUri: String, sampleCount: Int, promise: Promise) in
        //      // Send an event to JavaScript.
        //          DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
        //              Task {
        //                  if #available(iOS 15, *) {
        //                      let analyzer = WaveformAnalyzer()
        //                      guard let url = URL(string: localUri) else {
        //                          promise.reject("ERROR_INVALID_URL", "Failed to find asset at url \(localUri)")
        //                          return
        //                      }
        //                      let result = await process(path: url)
        ////                      let result = try await analyzer.samples(fromAudioAt: url, count: sampleCount)
        //                      promise.resolve(result)
        //                  } else {
        //                      // Fallback on earlier versions
        //                      promise.reject("ERROR_IOS_VERSION", "iOS version 15.0 or higher is required")
        //                  }
        //              }
        //            }
        //    }
        
        // Enables the module to be used as a native view. Definition components that are accepted as part of the
        // view definition: Prop, Events.
        View(ExpoAudioFFTView.self) {
            // Defines a setter for the `name` prop.
            Prop("name") { (view: ExpoAudioFFTView, prop: String) in
                print(prop)
            }
        }
    }
  }

