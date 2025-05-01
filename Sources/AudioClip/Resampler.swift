//
//  Resampler.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/31.
//

import AVFAudio

public final class Resampler {
    static let frameBufferLength = AVAudioFrameCount(8192)

    let sourceAudioFile: AVAudioFile
    let destinationAudioFile: AVAudioFile
    let sourceRange: ClosedRange<AVAudioFramePosition>?

    let converter: AVAudioConverter
    let sourceBuffer: AVAudioPCMBuffer
    let destinationBuffer: AVAudioPCMBuffer

    init(
        sourceAudioFile: AVAudioFile,
        destinationAudioFile: AVAudioFile,
        sourceRange: ClosedRange<AVAudioFramePosition>? = nil
    ) {
        self.sourceAudioFile = sourceAudioFile
        self.destinationAudioFile = destinationAudioFile
        self.sourceRange = sourceRange

        let sourceFormat = sourceAudioFile.processingFormat
        let destinationFormat = destinationAudioFile.processingFormat
        guard let converter = AVAudioConverter(
            from: sourceFormat,
            to: destinationFormat
        ) else {
            preconditionFailure("unable to create audio converter from \(sourceFormat) to \(destinationFormat)")
        }
        self.converter = converter

        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: Self.frameBufferLength * 4
        ) else {
            preconditionFailure("unable to create source buffer with format \(sourceFormat)")
        }

        self.sourceBuffer = sourceBuffer

        guard let destinationBuffer = AVAudioPCMBuffer(
            pcmFormat: destinationFormat,
            frameCapacity: Self.frameBufferLength * 4
        ) else {
            preconditionFailure("unable to create destination buffer with format \(destinationFormat)")
        }

        self.destinationBuffer = destinationBuffer
    }

    func resample() throws {
        if let sourceRange {
            sourceAudioFile.framePosition = sourceRange.lowerBound
        } else {
            sourceAudioFile.framePosition = 0
        }

        var error: NSError?
        while true {
            destinationBuffer.frameLength = 0
            let outputStatus = converter.convert(
                to: destinationBuffer,
                error: &error,
                withInputFrom: refill
            )

            switch outputStatus {
            case .haveData:
                try destinationAudioFile.write(from: destinationBuffer)
            case .endOfStream:
                return
            case .inputRanDry:
                preconditionFailure("no way! input ran dry?")
            case .error:
                if let error {
                    throw error
                } else {
                    preconditionFailure("unknown error occurred")
                }
            @unknown default:
                fatalError("unknown output status")
            }
        }
    }

    private func refill(
        numberOfFrames: AVAudioPacketCount,
        inputStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>
    ) -> AVAudioPCMBuffer {
        let framePosition = sourceAudioFile.framePosition
        let framesLeft: AVAudioFrameCount
        if let sourceRange {
            framesLeft = AVAudioFrameCount(sourceRange.upperBound - framePosition)
        } else {
            let totalFrames = sourceAudioFile.length
            framesLeft = AVAudioFrameCount(totalFrames - framePosition)
        }

        guard framesLeft > 0 else {
            inputStatus.pointee = .endOfStream
            return sourceBuffer
        }

        let framesToRead = min(
            min(AVAudioFrameCount(numberOfFrames), framesLeft),
            sourceBuffer.frameCapacity
        )
        do {
            try sourceAudioFile.read(into: sourceBuffer, frameCount: framesToRead)
        } catch {
            print(#fileID, "failed to read source audio \(framePosition)-\(framePosition + AVAudioFramePosition(framesToRead)): \(error)")
            inputStatus.pointee = .noDataNow
            return sourceBuffer
        }

        inputStatus.pointee = .haveData
        return sourceBuffer
    }
}
