package expo.modules.audiofft

import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.AudioProcessor.EMPTY_BUFFER
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.FloatArray
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.sqrt
import org.jtransforms.fft.FloatFFT_1D

class FFTAudioProcessor : AudioProcessor {
    private var inputEnded = false
    private lateinit var inputAudioFormat: AudioProcessor.AudioFormat
    private var buffer: ByteBuffer = EMPTY_BUFFER
    private var fftCallback: FFTCallback? = null
    private val fftSize = 2048
    var numBands = 20
    var bandingMethod = "logarithmic"
    private lateinit var smoothedBandMagnitudes: FloatArray
    private val smoothingFactor = 0.9f // Adjust this value to control smoothing (0.0 to 1.0)
    private lateinit var trends: FloatArray
    private val alpha = 0.1f // Smoothing factor for the level (0 < alpha < 1)
    private val beta = 0.05f // Smoothing factor for the trend (0 < beta < 1)

    private var floatArray: FloatArray = FloatArray(this.fftSize) { Float.NaN }
    private lateinit var magnitudes: FloatArray
    private lateinit var bandMagnitudes: FloatArray
    private lateinit var bandFrequencies: FloatArray

    private var numFramesToSkip = 2
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

    override fun configure(
            inputAudioFormat: AudioProcessor.AudioFormat
    ): AudioProcessor.AudioFormat {
        this.inputAudioFormat = inputAudioFormat
        println("Configuring...")
        // val fftSize = inputAudioFormat.bytesPerFrame * 8 // Assuming 16-bit audio
        magnitudes = FloatArray(fftSize / 2)
        bandMagnitudes = FloatArray(60)
        bandFrequencies = FloatArray(60)
        return inputAudioFormat // Return the same format, no changes
    }

    override fun isActive(): Boolean = true

    private fun generateLogFrequencies(count: Int, minFreq: Float, maxFreq: Float): FloatArray {
        val result = FloatArray(count)
        val logMin = log10(minFreq.toDouble())
        val logMax = log10(maxFreq.toDouble())
        val step = (logMax - logMin) / (count - 1)

        for (i in 0 until count) {
            result[i] = 10.0.pow(logMin + i * step).toFloat()
        }

        return result
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        //        inputBuffer.mark() // mark the current buffer position
        //        // Ensure the buffer has the correct byte order
        //        inputBuffer.order(ByteOrder.nativeOrder())
        //        // Process {fftSize} samples (assuming 16-bit PCM data)
        //        for (i in 0 until fftSize) {
        //            if (inputBuffer.remaining() >= 2) {
        //                // Get the next short from the buffer (2 bytes)
        //                val sample = inputBuffer.short
        //
        //                // Normalize the short to a float in the range -1.0 to 1.0
        //                floatArray[i] = sample.toFloat() / Short.MAX_VALUE.toFloat()
        //            }
        //        }
        //        inputBuffer.reset() // reset back to the position we were given, so the audio
        // renderer can use the data

        //        val numBands = 10
        //        val floatArray = FloatArray(10) { Random.nextFloat() }
        //        val bandMagnitudes = FloatArray(numBands) { Random.nextFloat() * 10f }
        //        val bandFrequencies = generateLogFrequencies(numBands, 20f, 20000f)
        //        val loudness = Random.nextFloat() * 40f
        //
        //        // Call the callback with random data
        //        if (nthFrame == numFramesToSkip) {
        //            nthFrame = 0
        //            fftCallback?.onFFTComputed(floatArray, bandMagnitudes, bandFrequencies,
        // loudness)
        //        } else {
        //            nthFrame++
        //        }
        //
        //        buffer = inputBuffer

        // Check if this.floatArray has all its values filled
        val remaining = inputBuffer.remaining()

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
                println(
                        "floatArray ${floatArray.size} ${floatArray[0]} ${floatArray[floatArray.size / 2]}"
                )
                inputBuffer
                        .reset() // reset back to the position we were given, so the audio renderer
                // can use the data

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
                if (bandingMethod === "logarithmic") {
                    calculateLogarithmicBands(floatArray, numBands)
                } else {
                    calculateLinearBands(
                        floatArray,
                        sampleRate.toDouble(),
                        0.0,
                        nyquistFrequency,
                        numBands
                    )
                }

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

    fun averageFrequencyInRange(
            startIdx: Int,
            endIdx: Int,
            fftSize: Int,
            sampleRate: Double
    ): Float {
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
            fftOutput: FloatArray,
            sampleRate: Double,
            minFrequency: Double,
            maxFrequency: Double,
            numberOfBands: Int
    ) {
        val nyquistFrequency = sampleRate / 2
        val actualMaxFrequency = minOf(nyquistFrequency, maxFrequency)

        if (!::smoothedBandMagnitudes.isInitialized) {
            smoothedBandMagnitudes = FloatArray(numberOfBands)
        }
        bandMagnitudes = FloatArray(numberOfBands)
        bandFrequencies = FloatArray(numberOfBands)

        val magLowerRange = magIndexForFreq(minFrequency, fftOutput.size, sampleRate)
        val magUpperRange = magIndexForFreq(actualMaxFrequency, fftOutput.size, sampleRate)

        val ratio: Float = (magUpperRange - magLowerRange).toFloat() / numberOfBands.toFloat()

        for (i in 0 until numberOfBands) {
            val magsStartIdx: Int = (floor(i * ratio)).toInt() + magLowerRange
            val magsEndIdx: Int = (floor((i + 1) * ratio)).toInt() + magLowerRange
            val magsAvg: Float =
                    if (magsEndIdx == magsStartIdx) {
                        calculateMagnitude(fftOutput, magsStartIdx)
                    } else {
                        fastAverageMagnitude(fftOutput, magsStartIdx, magsEndIdx)
                    }
            smoothedBandMagnitudes[i] =
                    smoothedBandMagnitudes[i] * (1 - smoothingFactor) + magsAvg * smoothingFactor
            bandMagnitudes[i] = magsAvg
            bandFrequencies[i] =
                    averageFrequencyInRange(magsStartIdx, magsEndIdx, fftOutput.size, sampleRate)
        }
    }

    fun calculateLogarithmicBands(fftData: FloatArray, numberOfBands: Int) {
        val fftSize = fftData.size
        val minFrequency = 20.0  // Minimum frequency (Hz)
        val maxFrequency = 20000.0  // Maximum frequency (Hz)

        // Calculate the range of frequencies covered by the FFT
        val frequencyRange = maxFrequency / minFrequency
        val bandFactor = Math.pow(frequencyRange, 1.0 / numberOfBands)

        // Initialize the array to store the band values
        val bandValues = FloatArray(numberOfBands) { 0.0f }

        // Calculate the bin index corresponding to the minimum frequency
        val minBin = (minFrequency / (maxFrequency / fftSize)).toInt()

        // Group FFT data into logarithmic bands
        for (bandIndex in 0 until numberOfBands) {
            // Calculate the lower and upper frequency bounds of the band
            val lowerFrequency = minFrequency * Math.pow(bandFactor, bandIndex.toDouble())
            val upperFrequency = minFrequency * Math.pow(bandFactor, (bandIndex + 1).toDouble())

            // Find the corresponding FFT bins for the band
            val lowerBin = (lowerFrequency / (maxFrequency / fftSize)).toInt()
            val upperBin = (upperFrequency / (maxFrequency / fftSize)).toInt()

            // Calculate the average value in the band
            if (lowerBin < fftSize) {
                val binCount = maxOf(1, upperBin - lowerBin)
                val bandValue = fftData.sliceArray(lowerBin until minOf(upperBin, fftSize)).sum() / binCount
                bandValues[bandIndex] = bandValue
            }
        }
        bandMagnitudes = bandValues
    }


    private fun calculateMagnitude(fftOutput: FloatArray, index: Int): Float {
        val real = fftOutput[index * 2]
        val imag = fftOutput[index * 2 + 1]
        return sqrt(real * real + imag * imag)
    }

    private fun fastAverageMagnitude(fftOutput: FloatArray, startIdx: Int, endIdx: Int): Float {
        var sum = 0f
        for (i in startIdx until endIdx step 2) {
            sum += calculateMagnitude(fftOutput, i / 2)
        }
        return sum / ((endIdx - startIdx) / 2)
    }
}
