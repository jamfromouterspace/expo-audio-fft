package expo.modules.audiofft

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.os.bundleOf
import androidx.media3.common.MediaItem
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.audio.DefaultAudioSink
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlin.math.sqrt

class ExpoAudioFFTModule : Module() {
    // Each module class must implement the definition function. The definition consists of
    // components
    // that describes the module's functionality and behavior.
    // See https://docs.expo.dev/modules/module-api for more details about available components.
    private var currentTime: Int = 0
    private lateinit var player: ExoPlayer
    private lateinit var handler: Handler
    private lateinit var updateProgressRunnable: Runnable
    private lateinit var fftProcessor: FFTAudioProcessor

    override fun definition() = ModuleDefinition {
        // Sets the name of the module that JavaScript code will use to refer to the module. Takes a
        // string as an argument.
        // Can be inferred from module's class name, but it's recommended to set it explicitly for
        // clarity.
        // The module will be accessible from `requireNativeModule('ExpoAudioFFT')` in JavaScript.
        Name("ExpoAudioFFT")

        // Defines event names that the module can send to JavaScript.
        Events("onAudioBuffer", "onProgress")

        Function("init") {
            handler = Handler(Looper.getMainLooper())
            handler.post {
                // Create a custom RenderersFactory that uses your AudioSink
                val renderersFactory =
                        object : DefaultRenderersFactory(appContext.reactContext!!) {
                            override fun buildAudioSink(
                                    context: Context,
                                    enableFloatOutput: Boolean,
                                    enableAudioTrackPlaybackParams: Boolean,
                                    enableOffload: Boolean
                            ): DefaultAudioSink {
                                // Create your FFTAudioProcessor
                                fftProcessor = FFTAudioProcessor()
                                fftProcessor.setFFTCallback {
                                        rawMagnitudes: FloatArray,
                                        bandMagnitudes: FloatArray,
                                        bandFrequencies: FloatArray,
                                        loudness: Float ->
                                    sendEvent(
                                            "onAudioBuffer",
                                            bundleOf(
                                                    "rawMagnitudes" to rawMagnitudes,
                                                    "bandMagnitudes" to bandMagnitudes,
                                                    "bandFrequencies" to bandFrequencies,
                                                    "loudness" to loudness,
                                                    "currentTime" to currentTime
                                            )
                                    )
                                    sendEvent("onProgress", bundleOf("currentTime" to currentTime))
                                }

                                // Create an array of AudioProcessors including your
                                // FFTAudioProcessor
                                val audioProcessors = arrayOf<AudioProcessor>(fftProcessor)

                                // Create a custom AudioSink with your processors
                                val audioSink =
                                        DefaultAudioSink.Builder(context)
                                                .setAudioProcessors(audioProcessors)
                                                .build()
                                return audioSink
                            }
                        }

                player =
                        ExoPlayer.Builder(appContext.reactContext!!)
                                .setRenderersFactory(renderersFactory)
                                .build()

                updateProgressRunnable =
                        object : Runnable {
                            override fun run() {
                                currentTime = (player.currentPosition / 1000).toInt()
                                sendEvent("onProgress", bundleOf("currentTime" to currentTime))
                                handler.postDelayed(this, 1000)
                            }
                        }
                handler.post(updateProgressRunnable)
            }
            Unit
        }

        Function("load") { localUri: String ->
            handler.post {
                val mediaItem = MediaItem.fromUri(Uri.parse(localUri))
                player.setMediaItem(mediaItem)
                player.prepare()
            }
        }

        Function("play") {
            handler.post { player.play() }
        }

        Function("pause") {
            handler.post {
                if (player.isPlaying) {
                    player.pause()
                    //              handler.removeCallbacks(updateProgressRunnable)
                }
            }
        }

        Function("seek") { toSeconds: Int ->
            player.seekTo(toSeconds * 1000L)
        }

        Function("currentTime") { currentTime }

        Function("setBandingOptions") { numBands: Int, bandingMethod: String ->
            if (::fftProcessor.isInitialized) {
                fftProcessor.numBands = numBands
                fftProcessor.bandingMethod = bandingMethod
            }
        }

        Function("getMetadata") { localUri: String ->
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(appContext.reactContext!!, Uri.parse(localUri), null)
                val format = extractor.getTrackFormat(0)

                val duration = format.getLong(MediaFormat.KEY_DURATION) / 1000 // Convert to seconds
                val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                val totalSamples = duration * sampleRate.toLong() * channelCount.toLong()

                bundleOf(
                        "duration" to duration,
                        "sampleRate" to sampleRate,
                        "totalSamples" to totalSamples,
                        "channelCount" to channelCount
                )
            } finally {
                extractor.release()
            }
        }

    }
}
