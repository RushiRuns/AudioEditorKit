//
//  AudioClipContentView+Waveform.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/6.
//

import AudioClip
import CoreGraphics
import Foundation
import UIKit
import WaveformAnalyzer

public extension AudioClipContentView {
    static let waveformWidth: CGFloat = 1
    static let waveformSpacing: CGFloat = 3
    static let waveformBucketWidth: CGFloat = waveformWidth + waveformSpacing

    static func drawWaveformInBounds(
        _ bounds: CGRect,
        audioClip: AudioClip,
        clipBounds: CGRect,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        let pointsPerSecond = Self.pointsPerSecond(with: zoomFactor)

        let beginX = max(0, bounds.minX - bounds.minX.truncatingRemainder(dividingBy: waveformBucketWidth))
        let endX = bounds.maxX
        let timeRange: ClosedRange<TimeInterval> = {
            let beginTime = TimeInterval(beginX / pointsPerSecond)
            let endTime = TimeInterval(endX / pointsPerSecond)
            return beginTime ... endTime
        }()

        let decimationFactor = Int((bounds.size.width / waveformBucketWidth).rounded(.up))
        guard let analysis = try? audioClip.acquireWaveformAnalysis(inTimeRange: timeRange, downsampledTo: decimationFactor),
              !analysis.amplitudes.isEmpty
        else {
            return
        }

        drawWaveformAnalysisInBounds(
            CGRect(
                x: beginX,
                y: bounds.minY,
                width: endX - beginX,
                height: bounds.size.height
            ),
            clipRange: clipBounds.minX ... clipBounds.maxX,
            analysis: analysis,
            in: ctx
        )
    }

    static func drawAlignedWaveformInBounds(
        _ bounds: CGRect,
        alignedTo middleTime: TimeInterval,
        audioClip: AudioClip,
        clipBounds: CGRect,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        let pointsPerSecond = Self.pointsPerSecond(with: zoomFactor)

        let clipTimeRange: ClosedRange<TimeInterval> = {
            let beginTime = max(0, middleTime - (bounds.midX - clipBounds.minX) / pointsPerSecond)
            let endTime = middleTime + (clipBounds.maxX - bounds.midX) / pointsPerSecond
            return beginTime ... endTime
        }()

        let actualWidth = (clipTimeRange.upperBound - clipTimeRange.lowerBound) * pointsPerSecond
        let decimationFactor = Int((actualWidth / waveformBucketWidth).rounded())
        guard let analysis = try? audioClip.acquireWaveformAnalysis(inTimeRange: clipTimeRange, downsampledTo: decimationFactor),
              !analysis.amplitudes.isEmpty
        else {
            return
        }

        drawWaveformAnalysisInBounds(
            clipBounds,
            analysis: analysis,
            in: ctx
        )
    }

    private static func drawWaveformAnalysisInBounds(
        _ bounds: CGRect,
        clipRange: ClosedRange<CGFloat>? = nil,
        analysis: WaveformAnalysis,
        in ctx: CGContext
    ) {
        ctx.saveGState()

        let path = CGMutablePath()
        let samples = analysis.amplitudes
        let sampleCount = samples.count

        var currX = bounds.minX
        var sampleIndex = 0

        while currX < bounds.maxX, sampleIndex < sampleCount {
            var sample = samples[sampleIndex]
            sample = clamp(1 - sample, to: 0 ... 1)

            var drawHeight = CGFloat(sample) * bounds.size.height
            if drawHeight < 1 {
                drawHeight = 1
            }

            let drawX = currX + waveformWidth / 2
            if let clipRange, currX + waveformBucketWidth > clipRange.upperBound {
                break
            }

            let drawY = bounds.minY + (bounds.size.height - drawHeight) / 2

            path.move(to: CGPoint(x: drawX, y: drawY))
            path.addLine(to: CGPoint(x: drawX, y: drawY + drawHeight))

            currX += waveformBucketWidth
            sampleIndex += 1
        }

        ctx.addPath(path)
        ctx.setLineCap(.butt)
        ctx.setStrokeColor(UIColor.label.cgColor)
        ctx.strokePath()

        ctx.restoreGState()
    }
}
