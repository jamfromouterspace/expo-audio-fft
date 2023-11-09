//
//  AudioMetadata.swift
//  ExpoAudioFFT
//
//  Created by Jamiel on 2023-11-08.
//

import Foundation
import AVFoundation

class AudioMetadata {
    let channelCount: UInt32
    let sampleRate: Double
    let totalSamples: UInt32
    let duration: Double
    let format: AVAudioFormat
    let file: AVAudioFile
    
    init(localUri: String) throws {
        file = try AVAudioFile(
            forReading: URL(string: localUri)!
        )
        format = file.processingFormat
        channelCount = format.channelCount
        sampleRate = format.sampleRate
        totalSamples = AVAudioFrameCount(file.length)
        duration = Double(totalSamples)/sampleRate
    }
}
