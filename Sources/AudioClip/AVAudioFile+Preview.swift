//
//  AVAudioFile+Preview.swift
//  TRApp
//
//  Created by Rachel on 12/20/24.
//

import AVFAudio

public extension AVAudioFile {
    var duration: TimeInterval {
        Double(length) / Double(fileFormat.sampleRate)
    }

    var fileForPreview: AVAudioFile? {
        try? AVAudioFile(forReading: url, commonFormat: .pcmFormatInt16, interleaved: true)
    }

    var estimatedFileSize: Int64 {
        length * Int64(processingFormat.streamDescription.pointee.mBytesPerFrame)
    }

    func estimatedFileSize(for duration: TimeInterval) -> Int64 {
        Int64(duration * processingFormat.sampleRate) * Int64(processingFormat.streamDescription.pointee.mBytesPerFrame)
    }
}
