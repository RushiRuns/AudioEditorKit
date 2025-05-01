//
//  AudioClip.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/20.
//

import AVFAudio
import Combine
import WaveformAnalyzer

public final class AudioClip {
    public let audioFile: AVAudioFile
    public var previewAudioFile: AVAudioFile? {
        didSet {
            resetWaveformAnalyzer()
        }
    }

    public init(contentsOf url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        startTime = 0
        endTime = audioFile.duration
        currentTime = 0
        isEditable = false
        isPlaying = false
        resetWaveformAnalyzer()
    }

    public var bitDepth: UInt32 { bitsPerChannel == 0 ? 32 : bitsPerChannel }
    public var bitsPerChannel: UInt32 { streamDescription.mBitsPerChannel }
    public var channelCount: AVAudioChannelCount { audioFile.fileFormat.channelCount }
    public var duration: TimeInterval { audioFile.duration }
    public var fileFormat: AVAudioFormat { audioFile.fileFormat }
    public var length: AVAudioFramePosition { audioFile.length }
    public var sampleRate: Double { audioFile.fileFormat.sampleRate }
    public var streamDescription: AudioStreamBasicDescription { audioFile.fileFormat.streamDescription.pointee }
    public var isPCMFormat: Bool { audioFile.fileFormat.commonFormat != .otherFormat }

    // MARK: - Internal

    var fileManager: FileManager?
    var removeWhenRelease: Bool = false

    deinit {
        if removeWhenRelease {
            try? (fileManager ?? .default).removeItem(at: audioFile.url)
            if let previewAudioFile {
                try? (fileManager ?? .default).removeItem(at: previewAudioFile.url)
            }
        }
    }

    // MARK: - Audio File Operations

    let audioReadLock = NSLock()

    public func duplicate(into newAudioFile: AVAudioFile) throws {
        try read(
            into: newAudioFile,
            frameCount: AVAudioFrameCount(audioFile.length),
            from: AVAudioFramePosition(0)
        )
    }

    public func read(
        into newAudioFile: AVAudioFile,
        frameCount: AVAudioFrameCount,
        from startFrame: AVAudioFramePosition
    ) throws {
        audioReadLock.lock()
        defer { audioReadLock.unlock() }

        let inputFormat = audioFile.processingFormat
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: Resampler.frameBufferLength
        ) else {
            preconditionFailure("unable to create input buffer")
        }

        let outputFormat = newAudioFile.processingFormat
        let outputBuffer: AVAudioPCMBuffer?
        let audioConverter: AVAudioConverter?
        let usesResampler: Bool

        if inputFormat.isEqual(outputFormat) {
            outputBuffer = nil
            audioConverter = nil
            usesResampler = false
        } else if Int64(inputFormat.sampleRate.rounded(.down)) != Int64(outputFormat.sampleRate.rounded(.down)) {
            outputBuffer = nil
            audioConverter = nil
            usesResampler = true
        } else {
            outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: Resampler.frameBufferLength
            )
            precondition(outputBuffer != nil, "unable to create output buffer")

            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
            precondition(audioConverter != nil, "unable to create audio converter")

            usesResampler = false
        }

        audioFile.framePosition = startFrame

        if usesResampler {
            let sourceRange = audioFile.framePosition ... (audioFile.framePosition + Int64(frameCount))
            let resampler = Resampler(
                sourceAudioFile: audioFile,
                destinationAudioFile: newAudioFile,
                sourceRange: sourceRange
            )

            try resampler.resample()

        } else {
            // sample rate conversion is not supported in this case
            var framesRemaining = frameCount
            while framesRemaining > 0 {
                let framesToRead = min(framesRemaining, inputBuffer.frameCapacity)
                try audioFile.read(into: inputBuffer, frameCount: framesToRead)

                let bufferToWrite: AVAudioPCMBuffer
                if let audioConverter, let outputBuffer {
                    try audioConverter.convert(to: outputBuffer, from: inputBuffer)
                    bufferToWrite = outputBuffer
                } else {
                    bufferToWrite = inputBuffer
                }

                try newAudioFile.write(from: bufferToWrite)
                framesRemaining -= framesToRead
            }
        }
    }

    // MARK: - User Interface

    @Published public var startTime: TimeInterval {
        didSet {
            reloadEditableState()
        }
    }

    @Published public var endTime: TimeInterval {
        didSet {
            reloadEditableState()
        }
    }

    public var timeRange: ClosedRange<TimeInterval> {
        startTime ... endTime
    }

    public var totalTimeRange: ClosedRange<TimeInterval> {
        0 ... duration
    }

    @Published public var currentTime: TimeInterval
    @Published public var isPlaying: Bool
    @Published public var zoomFactor: CGFloat?
    @Published public private(set) var isEditable: Bool

    public let inProgressEditorIdentifier = CurrentValueSubject<Int?, Never>(nil)

    private func reloadEditableState() {
        let editable = startTime > Self.minimumEditableInterval || endTime < duration - Self.minimumEditableInterval
        if isEditable != editable {
            isEditable = editable
        }
    }

    private static let minimumEditableInterval: TimeInterval = 1e-2

    // MARK: - Waveform

    private(set) var waveformAnalyzer: ContinuousWaveformAnalyzer!

    private func resetWaveformAnalyzer() {
        if let previewAudioFile {
            waveformAnalyzer = ContinuousWaveformAnalyzer(previewAudioFile)
        } else if let previewAudioFile = audioFile.fileForPreview {
            waveformAnalyzer = ContinuousWaveformAnalyzer(previewAudioFile)
        } else {
            preconditionFailure("unable to create waveform analyzer")
        }
    }
}
