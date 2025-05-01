//
//  ContinuousWaveformAnalyzer.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/5.
//

import Accelerate
@preconcurrency import AVFAudio

public class ContinuousWaveformAnalyzer: WaveformAnalyzer, @unchecked Sendable {
    public let audioFile: AVAudioFile

    public init(_ file: AVAudioFile) {
        audioFile = file
    }

    public func extract(
        inTimeRange timeRange: ClosedRange<TimeInterval>,
        downsampledTo targetSampleCount: Int
    ) throws -> WaveformAnalysis {
        guard targetSampleCount > 0,
              let frameRange = audioFile.frameRange(forTimeRange: timeRange)
        else {
            throw AnalyzeError.generic
        }

        return try extract(
            inFrameRange: frameRange,
            downsampledTo: targetSampleCount
        )
    }
}

private extension ContinuousWaveformAnalyzer {
    func extract(
        inFrameRange frameRange: ClosedRange<AVAudioFramePosition>,
        downsampledTo targetSampleCount: Int
    ) throws -> WaveformAnalysis {
        guard audioFile.isPCMFormatInt16Interleaved,
              let readBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(8192))
        else {
            preconditionFailure("unsupported audio format")
        }

        let startFrame = frameRange.lowerBound
        let endFrame = frameRange.upperBound
        let frameCount = AVAudioFrameCount(endFrame - startFrame)

        let streamDescription = audioFile.processingFormat.streamDescription.pointee
        precondition(streamDescription.mBitsPerChannel == 16, "only 16-bit PCM is supported")

        let channelCount = streamDescription.mChannelsPerFrame
        let sampleCount = Int(frameCount * channelCount)
        let samplesPerPixel = max(1, sampleCount / targetSampleCount)

        var outputSamples = [Float]()
        var sampleBuffer = Data()

        audioFile.framePosition = startFrame
        while audioFile.framePosition < audioFile.length {
            try audioFile.read(into: readBuffer)

            let readBufferLength = Int(readBuffer.frameLength * channelCount)
            guard let readBufferPointer = readBuffer.int16ChannelData?.pointee else {
                preconditionFailure("unable to get int-16 read buffer pointer")
            }

            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))

            let processedSamples = processPCMFormatInt16Buffer(sampleBuffer, downsampleTo: samplesPerPixel)
            outputSamples += processedSamples

            if outputSamples.count >= targetSampleCount {
                break
            }

            if processedSamples.count > 0 {
                sampleBuffer.removeFirst(processedSamples.count * samplesPerPixel * MemoryLayout<Int16>.size)
                sampleBuffer = Data(sampleBuffer)
            }
        }

        if outputSamples.count < targetSampleCount {
            let missingSampleCount = (targetSampleCount - outputSamples.count) * samplesPerPixel
            let backfillPaddingSampleCount = missingSampleCount - (sampleBuffer.count / MemoryLayout<Int16>.size)
            let backfillPaddingSampleCount16 = backfillPaddingSampleCount * MemoryLayout<Int16>.size
            let backfillPaddingSamples = [UInt8](repeating: 0, count: backfillPaddingSampleCount16)

            sampleBuffer.append(backfillPaddingSamples, count: backfillPaddingSampleCount16)

            let processedSamples = processPCMFormatInt16Buffer(sampleBuffer, downsampleTo: samplesPerPixel)
            outputSamples += processedSamples
        }

        let targetSamples = Array(outputSamples[0 ..< targetSampleCount])
        return WaveformAnalysis(amplitudes: normalize(targetSamples))
    }
}
