//
//  WaveformAnalyzer.swift
//  DSWaveformImage
//
//  Created by 82Flex on 2025/1/1.
//

import Accelerate
import Atomics
import AVFoundation
import Combine

/// Calculates the waveform of the initialized asset URL.
public class WaveformAnalyzer: @unchecked Sendable {
    enum AnalyzeError: Error {
        case emptyTracks
        case generic
        case readerError(AVAssetReader.Status)
        case userError
    }

    /// Everything below this noise floor cutoff will be clipped and interpreted as silence. Default is `-50.0`.
    public var noiseFloorDecibelCutoff: Float = -50.0

    public init() {}
    public func cancel() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private var cancellables = Set<AnyCancellable>()

    /// Calculates the amplitude envelope of the initialized audio asset URL, downsampled to the required `count` amount of samples.
    /// - Parameter fromAudioAt: local filesystem URL of the audio file to process.
    /// - Parameter count: amount of samples to be calculated. Downsamples.
    /// - Parameter qos: QoS of the DispatchQueue the calculations are performed (and returned) on.
    public func samples(fromAudioAt audioAssetURL: URL, count: Int, qos: DispatchQoS.QoSClass = .userInitiated) async throws -> [Float] {
        try await Task(priority: qos.taskPriority) {
            let audioAsset = AVURLAsset(url: audioAssetURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let assetReader = try AVAssetReader(asset: audioAsset)

            guard let assetTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
                throw AnalyzeError.emptyTracks
            }

            return try await waveformSamples(
                track: assetTrack,
                reader: assetReader,
                count: count,
                qos: qos
            ).amplitudes
        }.value
    }
}

extension WaveformAnalyzer {
    func processPCMFormatInt16Buffer(_ sampleBuffer: Data, downsampleTo samplesPerPixel: Int) -> [Float] {
        var downsampledData = [Float]()
        let sampleLength = sampleBuffer.count / MemoryLayout<Int16>.size

        guard sampleLength / samplesPerPixel > 0 else {
            return downsampledData
        }

        let unsafeSamplesPointer = sampleBuffer
            .withUnsafeBytes { $0.bindMemory(to: Int16.self) }
            .baseAddress!

        var loudestClipValue: Float = 0.0
        var quietestClipValue = noiseFloorDecibelCutoff

        // maximum amplitude storable in Int16 = 0 Db (loudest)
        var zeroDbEquivalent = Float(Int16.max)
        let samplesToProcess = vDSP_Length(sampleLength)

        var processingBuffer = [Float](repeating: 0.0, count: Int(samplesToProcess))

        // convert 16bit int to float (
        vDSP_vflt16(unsafeSamplesPointer, 1, &processingBuffer, 1, samplesToProcess)

        // absolute amplitude value
        vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, samplesToProcess)

        // convert to DB
        vDSP_vdbcon(processingBuffer, 1, &zeroDbEquivalent, &processingBuffer, 1, samplesToProcess, 1)
        vDSP_vclip(processingBuffer, 1, &quietestClipValue, &loudestClipValue, &processingBuffer, 1, samplesToProcess)

        let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
        let downsampledLength = sampleLength / samplesPerPixel
        downsampledData = [Float](repeating: 0.0, count: downsampledLength)

        vDSP_desamp(
            processingBuffer,
            vDSP_Stride(samplesPerPixel),
            filter,
            &downsampledData,
            vDSP_Length(downsampledLength),
            vDSP_Length(samplesPerPixel)
        )

        return downsampledData
    }

    func normalize(_ samples: [Float]) -> [Float] {
        samples.map { $0 / noiseFloorDecibelCutoff }
    }
}

private extension WaveformAnalyzer {
    func waveformSamples(
        track audioAssetTrack: AVAssetTrack,
        reader assetReader: AVAssetReader,
        count requiredNumberOfSamples: Int,
        qos: DispatchQoS.QoSClass = .userInitiated
    ) async throws -> WaveformAnalysis {
        guard requiredNumberOfSamples > 0 else {
            throw AnalyzeError.userError
        }

        let trackOutput = AVAssetReaderTrackOutput(
            track: audioAssetTrack,
            outputSettings: AVAudioFile.settingsPCMFormatInt16
        )

        assetReader.add(trackOutput)

        let totalSamples = try await totalSamples(ofAudioAssetTrack: audioAssetTrack)

        let task = Task(priority: qos.taskPriority) {
            let stop = ManagedAtomic<Bool>(false)
            return try await withTaskCancellationHandler {
                try extract(
                    totalSamples,
                    downsampledTo: requiredNumberOfSamples,
                    fromAssetReader: assetReader,
                    stop: stop
                )
            } onCancel: {
                stop.store(true, ordering: .relaxed)
            }
        }

        cancellables.insert(AnyCancellable(task.cancel))

        let analysis = try await task.value
        switch assetReader.status {
        case .completed, .cancelled:
            return analysis
        default:
            print("ERROR: reading waveform audio data has failed \(assetReader.status)")
            throw AnalyzeError.readerError(assetReader.status)
        }
    }

    private func extract(
        _ sampleCount: Int,
        downsampledTo targetSampleCount: Int,
        fromAssetReader assetReader: AVAssetReader,
        stop: ManagedAtomic<Bool>
    ) throws -> WaveformAnalysis {
        var outputSamples = [Float]()
        var sampleBuffer = Data()

        // read upfront to avoid frequent re-calculation (and memory bloat from C-bridging)
        let samplesPerPixel = max(1, sampleCount / targetSampleCount)

        assetReader.startReading()
        while assetReader.status == .reading {
            guard let trackOutput = assetReader.outputs.first,
                  let nextSampleBuffer = trackOutput.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(nextSampleBuffer)
            else {
                break
            }

            defer {
                CMSampleBufferInvalidate(nextSampleBuffer)
            }

            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>? = nil

            CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &readBufferLength,
                totalLengthOut: nil,
                dataPointerOut: &readBufferPointer
            )

            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))

            let processedSamples = processPCMFormatInt16Buffer(sampleBuffer, downsampleTo: samplesPerPixel)
            outputSamples += processedSamples

            if outputSamples.count >= targetSampleCount {
                assetReader.cancelReading()
                break
            }

            if processedSamples.count > 0 {
                // vDSP_desamp uses strides of samplesPerPixel; remove only the processed ones
                sampleBuffer.removeFirst(processedSamples.count * samplesPerPixel * MemoryLayout<Int16>.size)

                // this takes care of a memory leak
                sampleBuffer = Data(sampleBuffer)
            }

            if stop.load(ordering: .relaxed) {
                assetReader.cancelReading()
                throw CancellationError()
            }
        }

        // process leftover samples with padding to reach multiple of samplesPerPixel for vDSP_desamp
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

    private func totalSamples(ofAudioAssetTrack audioAssetTrack: AVAssetTrack) async throws -> Int {
        var totalSamples = 0
        let (descriptions, timeRange) = try await audioAssetTrack.load(.formatDescriptions, .timeRange)

        for formatDescription in descriptions {
            guard let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { continue }
            let channelCount = Int(basicDescription.pointee.mChannelsPerFrame)
            let sampleRate = basicDescription.pointee.mSampleRate
            totalSamples = Int(sampleRate * timeRange.duration.seconds) * channelCount
        }

        return totalSamples
    }
}
