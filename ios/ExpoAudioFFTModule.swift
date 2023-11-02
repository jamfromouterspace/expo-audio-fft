import ExpoModulesCore

public class ExpoAudioFFTModule: Module {
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
    Events("onChange")

    // Defines a JavaScript synchronous function that runs the native code on the JavaScript thread.
    Function("hello") {
      return "Hello world 2! 👋"
    }

    // Defines a JavaScript function that always returns a Promise and whose native code
    // is by default dispatched on the different thread than the JavaScript runtime runs on.
      AsyncFunction("getWaveformData") { (localUri: String, sampleCount: Int, promise: Promise) in
      // Send an event to JavaScript.
          DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
              Task {
                  if #available(iOS 15, *) {
                      let analyzer = WaveformAnalyzer()
                      guard let url = URL(string: localUri) else {
                          promise.reject("ERROR_INVALID_URL", "Failed to find asset at url \(localUri)")
                          return
                      }
                      let result = try await analyzer.samples(fromAudioAt: url, count: sampleCount)
                      promise.resolve(result.amplitudes)
                  } else {
                      // Fallback on earlier versions
                      promise.reject("ERROR_IOS_VERSION", "iOS version 15.0 or higher is required")
                  }
              }
            }
    }

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
