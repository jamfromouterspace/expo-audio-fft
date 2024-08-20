package expo.modules.audiofft

import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.AudioProcessor.EMPTY_BUFFER
import java.nio.ByteBuffer
import kotlin.math.sqrt
import org.jtransforms.fft.FloatFFT_1D
import java.lang.Math.random
import java.nio.ByteOrder
import kotlin.math.floor


class FFTAudioProcessor : AudioProcessor {
    private var inputEnded = false
    private lateinit var inputAudioFormat: AudioProcessor.AudioFormat
    private var buffer: ByteBuffer = EMPTY_BUFFER
    private var fftCallback: FFTCallback? = null

    private lateinit var floatArray: FloatArray
    private lateinit var magnitudes: FloatArray
    private lateinit var bandMagnitudes: FloatArray
    private lateinit var bandFrequencies: FloatArray

    private var numFramesToSkip = 5
    private var nthFrame = 0

    fun interface FFTCallback {
        fun onFFTComputed(
            rawMagnitudes: FloatArray,
            bandMagnitudes: FloatArray,
            bandFrequencies: FloatArray,
            loudness: Float
        )
    }

    fun setFFTCallback(callback: FFTCallback) {
        fftCallback = callback
    }

    override fun configure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        this.inputAudioFormat = inputAudioFormat
        println("Configuring...")
        val fftSize = inputAudioFormat.bytesPerFrame * 8 // Assuming 16-bit audio
        floatArray = FloatArray(fftSize)
        magnitudes = FloatArray(fftSize / 2)
        bandMagnitudes = FloatArray(60)
        bandFrequencies = FloatArray(60)
        return inputAudioFormat // Return the same format, no changes
    }

    override fun isActive(): Boolean = true

    override fun queueInput(inputBuffer: ByteBuffer) {
        // // Copy the input buffer to our internal buffer
        // if (buffer.capacity() < inputBuffer.remaining()) {
        //     buffer = ByteBuffer.allocate(inputBuffer.remaining())
        // }

        val remaining = inputBuffer.remaining()
        val fftSize = 2048

        if (remaining >= fftSize * 2) {
            if (nthFrame == numFramesToSkip) {
                nthFrame = 0
                inputBuffer.mark() // mark the current buffer position
                println("capacity ${inputBuffer.capacity()}")
                println("remaining ${inputBuffer.remaining()}")

                // Ensure the buffer has the correct byte order
                inputBuffer.order(ByteOrder.nativeOrder())

                // Create a FloatArray to hold the FFT input
                val floatArray = FloatArray(fftSize)

                // Process 2048 samples (assuming 16-bit PCM data)
                for (i in 0 until fftSize) {
                    if (inputBuffer.remaining() >= 2) {
                        // Get the next short from the buffer (2 bytes)
                        val sample = inputBuffer.short

                        // Normalize the short to a float in the range -1.0 to 1.0
                        floatArray[i] = sample.toFloat() / Short.MAX_VALUE.toFloat()
                    } else {
                        // If there's not enough data, fill the rest with zeros (padding)
                        floatArray[i] = 0.0f
                    }
                }
                println("floatArray ${floatArray.size} ${floatArray[0]} ${floatArray[floatArray.size / 2]}")
                inputBuffer.reset() // reset back to the position we were given, so the audio renderer can use the data

                println("floatArray ${floatArray.size} $floatArray")
                val fft = FloatFFT_1D(2048)

                val loudness = rms(floatArray)
                println("loudness $loudness")
                // Perform FFT
                fft.realForward(floatArray)

                println(floatArray)

                // Calculate band magnitudes and frequencies
                val sampleRate = inputAudioFormat.sampleRate
                val nyquistFrequency = (sampleRate / 2).toDouble()
                calculateLinearBands(floatArray, sampleRate.toDouble(), 0.0, nyquistFrequency, 60)

                // Calculate overall loudness (you may want to adjust this calculation)

                fftCallback?.onFFTComputed(floatArray, bandMagnitudes, bandFrequencies, loudness)
            } else {
                nthFrame++
            }
        }
        buffer = inputBuffer
    }

    private fun rms(array: FloatArray): Float {
        if (array.isEmpty()) return 0f
        var sum = 0f
        for (value in array) {
            sum += value * value
        }
        return sqrt(sum / array.size)
    }

    override fun queueEndOfStream() {
        // No special handling needed for end of stream
    }

    override fun getOutput(): ByteBuffer {
        // Return the current output buffer
        return buffer
    }

    override fun isEnded(): Boolean {
        // Check if processing is finished
        return inputEnded && buffer == EMPTY_BUFFER
    }

    override fun flush() {
        // Reset the processor state
        buffer = EMPTY_BUFFER
        inputEnded = false
    }

    override fun reset() {
        // Reset the processor completely
        flush()
    }

    fun averageFrequencyInRange(startIdx: Int, endIdx: Int, fftSize: Int, sampleRate: Double): Float {
        val nyquist = sampleRate / 2
        val freqStart = (startIdx.toDouble() / (fftSize / 2)) * nyquist
        val freqEnd = (endIdx.toDouble() / (fftSize / 2)) * nyquist
        return ((freqStart + freqEnd) / 2).toFloat()
    }

    fun fastAverage(array: FloatArray, startIdx: Int, endIdx: Int): Float {
        val sum = array.sliceArray(startIdx until endIdx).sum()
        return sum / (endIdx - startIdx)
    }

    fun magIndexForFreq(freq: Double, fftSize: Int, sampleRate: Double): Int {
        val nyquist = sampleRate / 2
        return ((freq / nyquist) * (fftSize / 2)).toInt()
    }

    fun calculateLinearBands(
        fftMagnitudes: FloatArray,
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double,
        numberOfBands: Int
    ) {
        val nyquistFrequency = sampleRate / 2
        val actualMaxFrequency = minOf(nyquistFrequency, maxFrequency)

        bandMagnitudes = FloatArray(numberOfBands)
        bandFrequencies = FloatArray(numberOfBands)

        val magLowerRange = magIndexForFreq(minFrequency, fftMagnitudes.size, sampleRate)
        val magUpperRange = magIndexForFreq(actualMaxFrequency, fftMagnitudes.size, sampleRate)

        val ratio: Float = (magUpperRange - magLowerRange).toFloat() / numberOfBands.toFloat()

        for (i in 0 until numberOfBands) {
            val magsStartIdx: Int = (floor(i * ratio)).toInt() + magLowerRange
            val magsEndIdx: Int = (floor((i + 1) * ratio)).toInt() + magLowerRange
            val magsAvg: Float = if (magsEndIdx == magsStartIdx) {
                fftMagnitudes[magsStartIdx]
            } else {
                fastAverage(fftMagnitudes, magsStartIdx, magsEndIdx)
            }
            bandMagnitudes[i] = magsAvg
            bandFrequencies[i] = averageFrequencyInRange(magsStartIdx, magsEndIdx, fftMagnitudes.size, sampleRate)
        }
    }
}