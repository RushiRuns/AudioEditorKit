//
//  AudioClipContext.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/20.
//

import AVFAudio
import Combine
import Foundation

public final class AudioClipContext: NSObject {
    static let cachesCleared: Bool = {
        do {
            try fileManager.removeItem(at: libraryDirectory)
            return true
        } catch {
            return false
        }
    }()

    public let initial: AudioClip
    public var current: CurrentValueSubject<AudioClip, Never>
    public var currentURL: URL { current.value.audioFile.url }
    public var currentPreviewURL: URL { current.value.previewAudioFile?.url ?? currentURL }
    public let temporaryDirectory: URL

    public var isAbleToSave: Bool { operationCount > 1 }

    private static let maximumPreviewLength: TimeInterval = 1800 // 30 minutes
    public var shouldRenderWaveform: Bool {
        current.value.isPCMFormat || current.value.duration < Self.maximumPreviewLength
    }

    static let fileManager = FileManager()
    static let libraryName = "wiki.qaq.AudioClipContext"
    static let libraryDirectory = fileManager
        .urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent(libraryName, isDirectory: true)
    private static let maximumOperationCount = 10

    private var operationCount = 1
    private let undoManager: UndoManager

    public init(contentsOf url: URL, undoManager: UndoManager = .init()) throws {
        initial = try AudioClip(contentsOf: url)
        current = CurrentValueSubject(initial)
        self.undoManager = undoManager

        temporaryDirectory = Self.libraryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try Self.fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        super.init()

        undoManager.levelsOfUndo = Self.maximumOperationCount

        print(#fileID, "audio clip context created")
    }

    deinit {
        try? Self.fileManager.removeItem(at: temporaryDirectory)
        print(#fileID, "audio clip context discard")
    }

    // MARK: - Public

    public func standardize() throws {
        precondition(operationCount > 0, "context is discarded")

        let duration = current.value.duration
        let newAudioName = temporaryDirectory
            .appendingPathComponent("\(operationCount)_" + UUID().uuidString)

        let newAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("caf"),
            settings: processingAudioSettings
        )

        try checkDiskSpace(requiredSpaceInBytes: newAudioFile.estimatedFileSize(for: duration))
        try current.value.duplicate(into: newAudioFile)

        let newAudioClip = try AudioClip(contentsOf: newAudioFile.url)
        newAudioClip.fileManager = Self.fileManager
        newAudioClip.removeWhenRelease = true

        let previewAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("preview")
                .appendingPathExtension("caf"),
            settings: previewAudioSettings
        )

        try checkDiskSpace(requiredSpaceInBytes: previewAudioFile.estimatedFileSize(for: duration))
        try newAudioClip.duplicate(into: previewAudioFile)
        newAudioClip.previewAudioFile = previewAudioFile.fileForPreview

        undoManager.removeAllActions(withTarget: self)

        operationCount = 1
        current.send(newAudioClip)

        print(#fileID, "audio clip standardized")
    }

    public func trim() throws {
        precondition(operationCount > 0, "context is discarded")

        let start = current.value.startTime
        let end = current.value.endTime

        guard start >= 0, end <= current.value.duration, start < end else {
            throw Error.invalidRange(start: start, end: end)
        }

        let duration = end - start
        let newAudioName = temporaryDirectory
            .appendingPathComponent("\(operationCount)_" + UUID().uuidString)

        let newAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("caf"),
            settings: processingAudioSettings
        )

        let startFrame = AVAudioFramePosition(start * current.value.sampleRate)
        let endFrame = AVAudioFramePosition(end * current.value.sampleRate)

        print(#fileID, "audio clip trim \(startFrame)-\(endFrame)")

        try checkDiskSpace(requiredSpaceInBytes: newAudioFile.estimatedFileSize(for: duration))
        try current.value.read(
            into: newAudioFile,
            frameCount: AVAudioFrameCount(endFrame - startFrame),
            from: startFrame
        )

        let newAudioClip = try AudioClip(contentsOf: newAudioFile.url)
        newAudioClip.fileManager = Self.fileManager
        newAudioClip.removeWhenRelease = true

        let previewAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("preview")
                .appendingPathExtension("caf"),
            settings: previewAudioSettings
        )

        try checkDiskSpace(requiredSpaceInBytes: previewAudioFile.estimatedFileSize(for: duration))
        try newAudioClip.duplicate(into: previewAudioFile)
        newAudioClip.previewAudioFile = previewAudioFile.fileForPreview

        try registerOperation(newAudioClip, index: operationCount + 1)
    }

    public func delete() throws {
        precondition(operationCount > 0, "context is discarded")

        let start = current.value.startTime
        let end = current.value.endTime

        guard start >= 0, end <= current.value.duration, start < end else {
            throw Error.invalidRange(start: start, end: end)
        }

        let duration = current.value.duration - end + start
        let newAudioName = temporaryDirectory
            .appendingPathComponent("\(operationCount)_" + UUID().uuidString)

        let newAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("caf"),
            settings: processingAudioSettings
        )

        let startFrame = AVAudioFramePosition(start * current.value.sampleRate)
        let endFrame = AVAudioFramePosition(end * current.value.sampleRate)

        print(#fileID, "audio clip delete \(startFrame)-\(endFrame)")

        try checkDiskSpace(requiredSpaceInBytes: newAudioFile.estimatedFileSize(for: duration))

        if startFrame > 0 {
            try current.value.read(
                into: newAudioFile,
                frameCount: AVAudioFrameCount(startFrame),
                from: 0
            )
        }

        if current.value.length > endFrame {
            try current.value.read(
                into: newAudioFile,
                frameCount: AVAudioFrameCount(current.value.length - endFrame),
                from: endFrame
            )
        }

        let newAudioClip = try AudioClip(contentsOf: newAudioFile.url)
        newAudioClip.fileManager = Self.fileManager
        newAudioClip.removeWhenRelease = true

        let previewAudioFile = try AVAudioFile(
            forWriting: newAudioName
                .appendingPathExtension("preview")
                .appendingPathExtension("caf"),
            settings: previewAudioSettings
        )

        try checkDiskSpace(requiredSpaceInBytes: previewAudioFile.estimatedFileSize(for: duration))
        try newAudioClip.duplicate(into: previewAudioFile)
        newAudioClip.previewAudioFile = previewAudioFile.fileForPreview

        try registerOperation(newAudioClip, index: operationCount + 1)
    }

    public func saveAs(_ url: URL, settings: [String: Any]) throws {
        precondition(operationCount > 0, "context is discarded")

        let duration = current.value.duration
        let newAudioFile = try AVAudioFile(forWriting: url, settings: settings)

        try checkDiskSpace(requiredSpaceInBytes: newAudioFile.estimatedFileSize(for: duration))
        try current.value.duplicate(into: newAudioFile)
    }

    public func saveAsTemporary(settings: [String: Any]) throws -> URL {
        precondition(operationCount > 0, "context is discarded")

        let newAudioName = temporaryDirectory
            .appendingPathComponent("\(operationCount)_" + UUID().uuidString)
            .appendingPathExtension(fileExtension(of: settings) ?? "caf")

        try saveAs(newAudioName, settings: settings)

        return newAudioName
    }

    public func save(settings: [String: Any]) throws {
        let newAudioName = try saveAsTemporary(settings: settings)

        try? Self.fileManager.removeItem(at: initial.audioFile.url)
        try Self.fileManager.moveItem(at: newAudioName, to: initial.audioFile.url)

        operationCount = -1
    }

    private func fileExtension(of settings: [String: Any]) -> String? {
        guard let format = settings[AVAudioFileTypeKey] as? AudioFileTypeID else {
            return nil
        }

        if format == kAudioFileM4AType {
            return "m4a"
        } else if format == kAudioFileWAVEType {
            return "wav"
        } else if format == kAudioFileCAFType {
            return "caf"
        } else {
            return nil
        }
    }

    // MARK: - Content Stack

    private func registerOperation(_ newAudioClip: AudioClip, index: Int) throws {
        precondition(operationCount > 0, "context is discarded")

        let oldAudioClip = current.value
        let oldOperationCount = operationCount

        undoManager.registerUndo(withTarget: self) {
            try? $0.registerOperation(oldAudioClip, index: oldOperationCount)
        }

        operationCount = index
        current.send(newAudioClip)

        print(#fileID, "audio clip registered operation #\(index)")
    }

    // MARK: - Internal

    private var processingAudioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: NSNumber(value: current.value.sampleRate),
            AVNumberOfChannelsKey: NSNumber(value: current.value.channelCount),
            AVLinearPCMBitDepthKey: NSNumber(value: current.value.bitDepth),
            AVLinearPCMIsFloatKey: NSNumber(value: false),
            AVLinearPCMIsBigEndianKey: NSNumber(value: false),
            AVLinearPCMIsNonInterleaved: NSNumber(value: false),
        ]
    }

    private var previewAudioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: NSNumber(value: 8000),
            AVNumberOfChannelsKey: NSNumber(value: current.value.channelCount),
            AVLinearPCMBitDepthKey: NSNumber(value: 16),
            AVLinearPCMIsFloatKey: NSNumber(value: false),
            AVLinearPCMIsBigEndianKey: NSNumber(value: false),
            AVLinearPCMIsNonInterleaved: NSNumber(value: false),
        ]
    }
}
