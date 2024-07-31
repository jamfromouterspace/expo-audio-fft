package expo.modules.audiofft

import android.media.AudioAttributes
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import android.media.MediaPlayer
import android.media.audiofx.Visualizer
import android.os.Handler
import androidx.core.os.bundleOf
import expo.modules.core.interfaces.Arguments

class ExpoAudioFFTModule : Module() {
  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.
  private var mediaPlayer: MediaPlayer? = null
  private var visualizer: Visualizer? = null
  private var currentTime: Int = 0

  override fun definition() = ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
    // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
    // The module will be accessible from `requireNativeModule('ExpoAudioFFT')` in JavaScript.
    Name("ExpoAudioFFT")

    // Defines event names that the module can send to JavaScript.
    Events("onAudioBuffer", "onProgress")

    Function("init") {
      // don't need this
    }

    Function("load") { localUri: String ->
      mediaPlayer?.release()
      visualizer?.release()

      mediaPlayer = MediaPlayer().apply {
        setAudioAttributes(
          AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .build()
        )
        setDataSource(localUri)
        prepare()
      }

      mediaPlayer?.setOnPreparedListener {
//        visualizer = Visualizer
//        setupVisualizer()
          println("successfully set up visualizer")
      }

      mediaPlayer?.setOnCompletionListener {
        visualizer?.enabled = false
      }
    }

    Function("play") {
      println("PLAY! ${mediaPlayer == null}")
      mediaPlayer?.start()
//      setupVisualizer()
//      visualizer = Visualizer(mediaPlayer!!.audioSessionId)
      startProgressUpdater()
    }

    Function("pause") {
      mediaPlayer?.pause()
    }

    Function("seek") { to: Int ->
      mediaPlayer?.seekTo(to * 1000) // Seek in milliseconds
    }

    Function("currentTime") {
      currentTime
    }

    Function("setBandingOptions") { numBands: Int, bandingMethod: String ->
      // Not implemented for simplicity
    }

    Function("getMetadata") { localUri: String ->
      mapOf(
        "duration" to mediaPlayer?.duration,
//        "sampleRate" to mediaPlayer!!.audio,
//        "totalSamples" to mediaPlayer!!.cha,
        "channelCount" to 2
      )
    }

    // Defines a JavaScript function that always returns a Promise and whose native code
    // is by default dispatched on the different thread than the JavaScript runtime runs on.
    AsyncFunction("setValueAsync") { value: String ->
      // Send an event to JavaScript.
      sendEvent("onChange", mapOf(
        "value" to value
      ))
    }

    // Enables the module to be used as a native view. Definition components that are accepted as part of
    // the view definition: Prop, Events.
    View(ExpoAudioFFTView::class) {
      // Defines a setter for the `name` prop.
      Prop("name") { view: ExpoAudioFFTView, prop: String ->
        println(prop)
      }
    }
  }

  private fun setupVisualizer() {
    mediaPlayer?.let {
      println("audio session id ${it.audioSessionId}")
      visualizer = Visualizer(it.audioSessionId).apply {
        println("1")
        captureSize = Visualizer.getCaptureSizeRange()[1]
        println("2")
//        setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
//          override fun onWaveFormDataCapture(visualizer: Visualizer?, waveform: ByteArray?, samplingRate: Int) {
//            println("onWaveFormDataCapture ${waveform}")
////            waveform?.let { data ->
////              this@ExpoAudioFFTModule.sendEvent("onAudioBuffer", bundleOf(
////                "rawMagnitudes" to
////              ))
////              sendEvent("onAudioBuffer", Arguments.createMap().apply {
////                putArray("rawMagnitudes", Arguments.fromArray(data.map { it.toInt() }.toTypedArray()))
////                putDouble("currentTime", currentTime.toDouble())
////              })
////            }
//          }
//
//          override fun onFftDataCapture(visualizer: Visualizer?, fft: ByteArray?, samplingRate: Int) {
//            // FFT Data not used for now
//            println("onFftDataCapture ${fft}")
//          }
//        }, Visualizer.getMaxCaptureRate() / 2, true, true)
        enabled = true
      }
    }
  }

  private fun startProgressUpdater() {
    val handler = Handler()
    val runnable = object : Runnable {
      override fun run() {
        mediaPlayer?.let {
          if (it.isPlaying) {
            currentTime = it.currentPosition / 1000
            println("currentTime $currentTime")
            sendEvent("onProgress", mapOf(
                "currentTime" to currentTime.toDouble()
            ))
            handler.postDelayed(this, 1000)
          }
        }
      }
    }
    handler.post(runnable)
  }
}
