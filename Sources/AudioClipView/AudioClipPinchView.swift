//
//  AudioClipPinchView.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/30.
//

import AudioClip
import UIKit

public final class AudioClipPinchView: UIView {
    // 在双指捏合缩放状态下的替代视图
    // 用于缓解 CATiledLayer 异步绘制的闪烁问题

    weak var audioClip: AudioClip? {
        didSet {
            setNeedsDisplay()
        }
    }

    init() {
        super.init(frame: .zero)
        _commonInit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func _commonInit() {
        _setupCommonAttributes()
    }

    private func _setupCommonAttributes() {
        alpha = 0.9975
        backgroundColor = .systemBackground
    }

    // MARK: - Public

    var drawValues = AudioClipDrawValues() {
        didSet {
            setNeedsDisplay()
        }
    }

    override public func hitTest(_: CGPoint, with _: UIEvent?) -> UIView? {
        nil
    }

    // MARK: - Draw

    override public func draw(_: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !isHidden else {
            return
        }

        // 绘制底板
        let realBounds = CGRect(
            x: bounds.minX,
            y: bounds.minY + AudioClipControlView.anchorCircleSpacing,
            width: bounds.width,
            height: bounds.height - AudioClipControlView.anchorCircleSpacing
        )
        let backgroundRect = CGRect(
            x: realBounds.minX,
            y: realBounds.minY,
            width: realBounds.width,
            height: realBounds.height - AudioClipContentView.rulerHeight
        )
        Self.drawBackgroundInBounds(backgroundRect, in: ctx)

        // 绘制背景
        let middleX = realBounds.midX + drawValues.alignedOffsetX
        func convertRect(xRange: ClosedRange<CGFloat>, height: CGFloat) -> CGRect {
            let leftWidth = (middleX - xRange.lowerBound) * drawValues.pinchFactor
            let rightWidth = (xRange.upperBound - middleX) * drawValues.pinchFactor
            return CGRect(
                x: max(realBounds.minX, realBounds.midX - leftWidth),
                y: realBounds.minY,
                width: min(leftWidth, realBounds.midX) + min(rightWidth, realBounds.midX),
                height: height
            )
        }
        let fillBackgroundRect = convertRect(
            xRange: realBounds.minX ... drawValues.contentWidth, height: realBounds.height
        )
        AudioClipContentView.drawBackgroundInBounds(fillBackgroundRect, in: ctx)

        // 绘制标尺
        let middleTime = TimeInterval(middleX / AudioClipContentView.pointsPerSecond(with: drawValues.zoomFactor))
        let zoomFactor = drawValues.zoomFactor * drawValues.pinchFactor
        AudioClipContentView.drawAlignedRulerInBounds(
            realBounds,
            alignedTo: middleTime,
            zoomFactor: zoomFactor,
            in: ctx
        )

        guard let audioClip else {
            return
        }

        // 绘制波形
        if !fillBackgroundRect.isEmpty {
            var waveformRect = fillBackgroundRect
            waveformRect.size.height = realBounds.height - AudioClipContentView.rulerHeight
            if waveformRect.minX < 1e-3 {
                let diffX = drawValues.alignedOffsetX
                    .truncatingRemainder(dividingBy: AudioClipContentView.waveformBucketWidth)
                waveformRect.origin.x -= diffX
            }
            AudioClipContentView.drawAlignedWaveformInBounds(
                realBounds,
                alignedTo: middleTime,
                audioClip: audioClip,
                clipBounds: waveformRect,
                zoomFactor: zoomFactor,
                in: ctx
            )
        }

        // 绘制蒙层
        let startX = drawValues.contentWidth * CGFloat(audioClip.startTime / audioClip.duration)
        let endX = drawValues.contentWidth * CGFloat(audioClip.endTime / audioClip.duration)
        let maskRect = convertRect(xRange: startX ... endX, height: backgroundRect.height)
        AudioClipControlView.drawControlMaskInBounds(maskRect, in: ctx)

        // 绘制中心线
        let shouldDrawCenterIndicator = maskRect.minX + 1.0 < realBounds.midX && realBounds.midX < maskRect.maxX - 1.0
        if shouldDrawCenterIndicator {
            AudioClipControlView.drawAnchor(
                x: realBounds.midX,
                yRange: maskRect.minY ... maskRect.maxY,
                color: AudioClipControlView.indicatorColor.cgColor,
                in: ctx
            )
        }

        // 绘制锚点
        let anchorRangeX = realBounds.minX - AudioClipControlView.anchorCircleRadius ... realBounds.maxX + AudioClipControlView.anchorCircleRadius
        let beginAnchorX = realBounds.midX - (realBounds.midX + drawValues.alignedOffsetX - startX) * drawValues.pinchFactor
        let shouldDrawBeginAnchor = anchorRangeX ~= beginAnchorX
        if shouldDrawBeginAnchor {
            AudioClipControlView.drawAnchor(
                x: beginAnchorX,
                yRange: maskRect.minY ... maskRect.maxY,
                color: AudioClipControlView.backgroundColor.cgColor,
                in: ctx
            )
        }
        let endAnchorX = realBounds.midX + (endX - realBounds.midX - drawValues.alignedOffsetX) * drawValues.pinchFactor
        let shouldDrawEndAnchor = anchorRangeX ~= endAnchorX
        if shouldDrawEndAnchor {
            AudioClipControlView.drawAnchor(
                x: endAnchorX,
                yRange: maskRect.minY ... maskRect.maxY,
                color: AudioClipControlView.backgroundColor.cgColor,
                in: ctx
            )
        }
    }

    private static func drawBackgroundInBounds(
        _ bounds: CGRect,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        ctx.setAlpha(0.33)
        ctx.setFillColor(AudioClipContentView.backgroundColor.cgColor)
        ctx.fill(bounds)
        ctx.restoreGState()
    }
}
