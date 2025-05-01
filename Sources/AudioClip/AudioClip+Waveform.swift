//
//  AudioClip+Waveform.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/1.
//

import Foundation
import WaveformAnalyzer

public extension AudioClip {
    func acquireWaveformAnalysis(
        inTimeRange timeRange: ClosedRange<TimeInterval>,
        downsampledTo targetSampleCount: Int
    ) throws -> WaveformAnalysis {
        try audioReadLock.withLock {
            try waveformAnalyzer.extract(
                inTimeRange: timeRange,
                downsampledTo: targetSampleCount
            )
        }
    }
}
