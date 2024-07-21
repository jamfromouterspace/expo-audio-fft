import AVFoundation
import Accelerate
import Foundation

class AudioProcessor {
//    static var shared: AudioProcessor = .init()
    
    private let engine = AVAudioEngine()
    private let bufferSize = 1024
    private var metadata: AudioMetadata?
    private var startFrom: AVAudioFramePosition?
    private var currentTimeOffset: Double = 0.0 // this is because when we seek, the playerTime sample count resets to 0
    var numBands: Int = 80
    var currentTime: Double = 0.0
    var bandingMethod: String = "logarithmic"
    var onData: (_ rawMagnitudes: [Float], _ bandMagnitudes: [Float], _ bandFrequencies: [Float], _ loudness: Float, _ currentTime: Double) -> Void
    var nyquistFrequency: Double {
        get {
            if metadata == nil {
                return -1
            } else {
                return metadata!.sampleRate / 2.0
            }
        }
    }
    
    private let player = AVAudioPlayerNode()
    var fftMagnitudes: [Float] = []
    var fftFrequencies: [Float] = []
    var loudness: Float = 0
    var bandwidth: Double {
        get {
            if self.fftMagnitudes.count == 0 {
                return 0
            } else {
                return self.nyquistFrequency / Double(self.fftMagnitudes.count)
            }
        }
    }
    
    func play() {
        restartEngine()
        if metadata == nil || player.engine == nil || !player.engine!.isRunning {
            return
        }
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        if startFrom != nil {
            if startFrom! < 0 {
                startFrom = 0
            }
            let diff = metadata!.totalSamples - UInt32(startFrom!)
            let frameCount = AVAudioFrameCount(diff > 0 ? diff : 0)
            player.stop()
            player.scheduleSegment(metadata!.file, startingFrame: startFrom!, frameCount: frameCount, at: nil)
            player.play()
            startFrom = nil
        } else {
            player.play()
        }
    }
    func pause() {
        if metadata == nil || player.engine == nil || !player.engine!.isRunning {
            return
        }
        player.pause()
    }
    func stop() {
        startFrom = nil
        currentTimeOffset = 0
        currentTime = 0
        player.stop()
    }
    
    func seek(to: Double) -> Double? {
        if metadata == nil {
            print("Error: audio file not loaded (seek)")
            return nil
        }
        if let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime), player.isPlaying {
            player.stop()
            let sampleRate = playerTime.sampleRate // we could also use metadata.sampleRate, but playerTime has to be non-nil for this to work
            let frames = Int64(to * sampleRate)
            print("to: \(to)", "frames: \(frames)", "total samples: \(metadata!.totalSamples)")
            let newPlayerTime = AVAudioTime(sampleTime: AVAudioFramePosition(frames), atRate: sampleRate)
            let newNodeTime = player.nodeTime(forPlayerTime: newPlayerTime)
            let frameCount = AVAudioFrameCount(max(1, Int64(metadata!.totalSamples) - frames))
            player.scheduleSegment(metadata!.file, startingFrame: AVAudioFramePosition(frames), frameCount: frameCount, at: nil, completionHandler: nil)
            player.play()
            currentTimeOffset = to
            return to
        } else {
            currentTimeOffset = to
            startFrom = AVAudioFramePosition(Int(to * metadata!.sampleRate))
            return to
        }
    }

    
    init(onData: @escaping (_ rawMagnitudes: [Float], _ bandMagnitudes: [Float], _ bandFrequencies: [Float], _ loudness: Float, _ currentTime: Double) -> Void) {
        self.onData = onData
        startEngine()
    }
    
    func restartEngine() {
        if player.engine != nil && !player.engine!.isRunning {
            print("restarting engine...")
            // restart audio engine
            startEngine()
            seek(to: currentTime)
        }
    }
    
    func startEngine() {
        // initialize the main mixer node singleton
        _ = engine.mainMixerNode
        
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        
        engine.prepare()
        try! engine.start()
                
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.detach(player)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
                
        let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(bufferSize),
            vDSP_DFT_Direction.FORWARD
        )
                    
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: UInt32(bufferSize),
            format: nil
        ) { [self] buffer, time in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            if player.isPlaying && player.engine != nil && player.engine!.isRunning {
                let frames = buffer.frameLength
                loudness = rms( data: channelData, frameLength: UInt(frames))
                let rawMagnitudes = fft(data: channelData, setup: fftSetup!)
                fftMagnitudes = rawMagnitudes
//                let bands = calculateLogarithmicBands(minFrequency: 0, maxFrequency: nyquistFrequency, bandsPerOctave: numBands)
//                let bandMagnitudes = compressArray(inputArray: fftMagnitudes, compressionFactor: fftMagnitudes.count/60, method: AggregationMethod.average)
                var bandMagnitudes: [Float]
                var bandFrequencies: [Float] = []
                if bandingMethod == "linear" {
                    let bands = calculateLinearBands(minFrequency: 0, maxFrequency: nyquistFrequency, numberOfBands: numBands)
                    bandMagnitudes = bands.0
                    bandFrequencies = bands.1
                } else if bandingMethod == "avg" {
                    bandMagnitudes = compressArray(inputArray: rawMagnitudes, compressionFactor: rawMagnitudes.count/numBands, method: .average)
                } else if bandingMethod == "min" {
                    bandMagnitudes = compressArray(inputArray: rawMagnitudes, compressionFactor: rawMagnitudes.count/numBands, method: .min)
                } else if bandingMethod == "max" {
                    bandMagnitudes = compressArray(inputArray: rawMagnitudes, compressionFactor: rawMagnitudes.count/numBands, method: .max)
                } else {
                    bandMagnitudes = calculateLogarithmicBands(fftData: rawMagnitudes, numberOfBands: numBands)
                }
                setCurrentTime()
                // send to JS thread
                onData(fftMagnitudes, bandMagnitudes, bandFrequencies, loudness, currentTime)
                if metadata != nil && currentTime >= metadata!.duration {
                    player.pause()
                }
            }
        }
    }
    
    func setBandingOptions(numBands: Int, bandingMethod: String) {
        self.numBands = numBands
        self.bandingMethod = bandingMethod
    }
    
    func set(n: Int) {
        numBands = n
    }
    
    
    func load(localUri: String) {
        restartEngine()
        startFrom = nil
        currentTimeOffset = 0
        currentTime = 0
        metadata = try! AudioMetadata(localUri: localUri)
        player.stop()
        player.scheduleFile(metadata!.file, at: nil)
    }
    
    func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
        var realIn = [Float](repeating: 0, count: bufferSize)
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        
        // nyquist-shannon sampling theorem
        // the frequencies range from ~40Hz to ~20kHz
        let numFrequencyBins = bufferSize/2
            
        for i in 0 ..< bufferSize {
            realIn[i] = data[i]
        }
//        var window: [Float]?
//        if windowType != .none {
//            window = [Float](repeating: 0.0, count: size)
//            
//            switch windowType {
//            case .hamming:
//                vDSP_hann_window(&window!, UInt(size), Int32(vDSP_HANN_NORM))
//            case .hanning:
//                vDSP_hamm_window(&window!, UInt(size), 0)
//            default:
//                break
//            }
//            // Apply the window
//            vDSP_vmul(inMonoBuffer, 1, window!, 1, &analysisBuffer, 1, UInt(inMonoBuffer.count))
//        }
        
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
        var magnitudes = [Float](repeating: 0, count: numFrequencyBins)
        
        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer { imagBP in
                var complex = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(numFrequencyBins))
            }
        }
        
        var normalizedMagnitudes = [Float](repeating: 0.0, count: numFrequencyBins)
        var scalingFactor = Float(25.0/512)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(numFrequencyBins))
        return normalizedMagnitudes
    }
    
    func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_measqv(data, 1, &val, frameLength)
        var db = 10*log10f(val)
        //inverse dB to +ve range where 0(silent) -> 160(loudest)
        db = 160 + db;
        //Only take into account range from 120->160, so FSR = 40
        db = db - 120
        let dividor = Float(40/0.3)
        var adjustedVal = 0.3 + db/dividor

        //cutoff
        if (adjustedVal < 0.3) {
            adjustedVal = 0.3
        } else if (adjustedVal > 0.6) {
            adjustedVal = 0.6
        }

        return adjustedVal
    }
    
    func calculateLinearBands(minFrequency: Double, maxFrequency: Double, numberOfBands: Int) -> ([Float], [Float]) {
        assert(fftMagnitudes.count > 0, "*** Perform the FFT first.")
        
        let actualMaxFrequency = min(self.nyquistFrequency, maxFrequency)
        
        var bandMagnitudes = [Float](repeating: 0.0, count: numberOfBands)
        var bandFrequencies = [Float](repeating: 0.0,count: numberOfBands)
        
        let magLowerRange = magIndexForFreq(freq: minFrequency)
        let magUpperRange = magIndexForFreq(freq: actualMaxFrequency)
        let ratio: Float = Float(magUpperRange - magLowerRange) / Float(numberOfBands)
        
        for i in 0..<numberOfBands {
            let magsStartIdx: Int = Int(floorf(Float(i) * ratio)) + magLowerRange
            let magsEndIdx: Int = Int(floorf(Float(i + 1) * ratio)) + magLowerRange
            var magsAvg: Float
            if magsEndIdx == magsStartIdx {
                // Can happen when numberOfBands < # of magnitudes. No need to average anything.
                magsAvg = self.fftMagnitudes[magsStartIdx]
            } else {
                magsAvg = fastAverage(array: self.fftMagnitudes, magsStartIdx, magsEndIdx)
            }
            bandMagnitudes[i] = magsAvg
            bandFrequencies[i] = averageFrequencyInRange(startIndex: magsStartIdx, magsEndIdx)
        }
        return (bandMagnitudes, bandFrequencies)
        //        self.bandMinFreq = self.bandFrequencies[0]
        //        self.bandMaxFreq = self.bandFrequencies.last
    }
    
    
    @inline(__always) private func magsInFreqRange(lowFreq: Double, _ highFreq: Double) -> [Float] {
        let lowIndex = Int(lowFreq / self.bandwidth)
        var highIndex = Int(highFreq / self.bandwidth)
        
        if (lowIndex == highIndex) {
            // Occurs when both params are so small that they both fall into the first index
            highIndex += 1
        }
        
        return Array(self.fftMagnitudes[lowIndex..<highIndex])
    }
    
    private func magIndexForFreq(freq: Double) -> Int {
        assert(fftMagnitudes.count > 0, "*** Perform the FFT first.")
        return Int(Double(self.fftMagnitudes.count) * freq / self.nyquistFrequency)
    }
    
    @inline(__always) private func fastAverage(array:[Float], _ startIdx: Int, _ stopIdx: Int) -> Float {
        var mean: Float = 0
//        let ptr = UnsafePointer<Float>(array)
//        vDSP_meanv(ptr + startIdx, 1, &mean, UInt(stopIdx - startIdx))
        array.withUnsafeBufferPointer { bufferPointer in
            vDSP_meanv(bufferPointer.baseAddress! + startIdx, 1, &mean, UInt(stopIdx - startIdx))
        }
        return mean
    }
    
    @inline(__always) private func averageFrequencyInRange(startIndex: Int, _ endIndex: Int) -> Float {
        let startFrequency =  bandwidth * Double(startIndex)
        let endFrequency = bandwidth * Double(endIndex)
        return Float((startFrequency + endFrequency) / 2)
    }
    
    func setCurrentTime() -> Void {
        if self.metadata == nil {
            self.currentTime = 0
        } else if let nodeTime = self.player.lastRenderTime, let playerTime = self.player.playerTime(forNodeTime: nodeTime) {
            self.currentTime = self.currentTimeOffset + Double(playerTime.sampleTime) / self.metadata!.sampleRate
        } else {
            self.currentTime = 0
        }
    }
}


enum AggregationMethod {
    case average
    case max
    case min
}

func compressArray(inputArray: [Float], compressionFactor: Int, method: AggregationMethod) -> [Float] {
    let inputCount = inputArray.count
    
    // Ensure the compression factor is within valid bounds
    let validCompressionFactor = max(1, min(inputCount, compressionFactor))
    
    // Initialize an empty array for the compressed data
    var compressedData = [Float]()
    
    for i in stride(from: 0, to: inputCount, by: validCompressionFactor) {
        let startIndex = i
        let endIndex = min(i + validCompressionFactor, inputCount)
        
        switch method {
        case .average:
            // Calculate the average of the elements in the group
            let groupAverage = inputArray[startIndex..<endIndex].reduce(0, +) / Float(validCompressionFactor)
            compressedData.append(groupAverage)
        case .max:
            // Find the maximum value in the group
            if let groupMax = inputArray[startIndex..<endIndex].max() {
                compressedData.append(groupMax)
            }
        case .min:
            // Find the minimum value in the group
            if let groupMin = inputArray[startIndex..<endIndex].min() {
                compressedData.append(groupMin)
            }
        }
    }
    
    return compressedData
}



func calculateLogarithmicBands(fftData: [Float], numberOfBands: Int) -> [Float] {
    let fftSize = fftData.count
    let minFrequency: Double = 20.0  // Minimum frequency (Hz)
    let maxFrequency: Double = 20000.0  // Maximum frequency (Hz)

    // Calculate the range of frequencies covered by the FFT
    let frequencyRange = maxFrequency / minFrequency
    let bandFactor = pow(frequencyRange, 1.0 / Double(numberOfBands))

    // Initialize the array to store the band values
    var bandValues = [Float](repeating: 0.0, count: numberOfBands)

    // Calculate the bin index corresponding to the minimum frequency
    let minBin = Int(minFrequency / (maxFrequency / Double(fftSize)))

    // Group FFT data into logarithmic bands
    for bandIndex in 0..<numberOfBands {
        // Calculate the lower and upper frequency bounds of the band
        let lowerFrequency = minFrequency * pow(bandFactor, Double(bandIndex))
        let upperFrequency = minFrequency * pow(bandFactor, Double(bandIndex + 1))

        // Find the corresponding FFT bins for the band
        let lowerBin = Int(lowerFrequency / (maxFrequency / Double(fftSize)))
        let upperBin = Int(upperFrequency / (maxFrequency / Double(fftSize)))

        // Calculate the average value in the band
        if lowerBin < fftSize {
            let binCount = max(1, upperBin - lowerBin)
            let bandValue = fftData[lowerBin...min(upperBin, fftSize - 1)].reduce(0.0, +) / Float(binCount)
            bandValues[bandIndex] = bandValue
        }
    }

    return bandValues
}
