//
//  WaveformAnalysis.swift
//  DSWaveformImage
//
//  Created by 82Flex on 2025/1/1.
//

import Foundation

public struct WaveformAnalysis: Codable, Sendable {
    public let amplitudes: [Float]

    public init(amplitudes: [Float]) {
        self.amplitudes = amplitudes
    }
}
