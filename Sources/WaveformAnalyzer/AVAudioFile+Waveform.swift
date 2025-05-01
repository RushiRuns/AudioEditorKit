//
//  AVAudioFile+Waveform.swift
//  DSWaveformImage
//
//  Created by 82Flex on 2025/1/1.
//

import AVFAudio

extension AVAudioFile {
    var isPCMFormatInt16Interleaved: Bool {
        let streamDescription = processingFormat.streamDescription.pointee
        return
            streamDescription.mBitsPerChannel == 16 &&
            (streamDescription.mFormatFlags & kAudioFormatFlagIsFloat == 0) &&
            (streamDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0)
    }

    var totalFrameRange: ClosedRange<AVAudioFramePosition> {
        0 ... AVAudioFramePosition(length)
    }

    static var settingsPCMFormatInt16: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: NSNumber(value: 16),
            AVLinearPCMIsBigEndianKey: NSNumber(value: false),
            AVLinearPCMIsFloatKey: NSNumber(value: false),
            AVLinearPCMIsNonInterleaved: NSNumber(value: false),
        ]
    }

    func frameRange(forTimeRange timeRange: ClosedRange<TimeInterval>) -> ClosedRange<AVAudioFramePosition>? {
        let sampleRate = processingFormat.sampleRate
        let startFrame = max(0, AVAudioFramePosition(timeRange.lowerBound * sampleRate))
        let endFrame = min(AVAudioFramePosition(timeRange.upperBound * sampleRate), AVAudioFramePosition(length))
        guard startFrame < endFrame else {
            return nil
        }
        return startFrame ... endFrame
    }
}
