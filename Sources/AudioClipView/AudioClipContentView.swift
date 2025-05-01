//
//  AudioClipContentView.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/29.
//

import Atomics
import AudioClip
import UIKit

public final class AudioClipContentView: UIView {
    public weak var audioClip: AudioClip? {
        didSet {
            setNeedsDisplay()
        }
    }

    public var zoomFactor: CGFloat = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    override public class var layerClass: AnyClass {
        AudioClipContentLayer.self
    }

    public var tiledLayer: CATiledLayer {
        layer as! CATiledLayer
    }

    private let isAllowedToDraw: ManagedAtomic<Bool>

    public init(isAllowedToDraw: ManagedAtomic<Bool>) {
        self.isAllowedToDraw = isAllowedToDraw
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
        backgroundColor = .clear
    }

    override public var intrinsicContentSize: CGSize {
        if let audioClip {
            CGSize(
                width: CGFloat(audioClip.duration) * pointsPerSecond,
                height: UIView.noIntrinsicMetric
            )
        } else {
            CGSize(width: 0, height: UIView.noIntrinsicMetric)
        }
    }

    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        guard isAllowedToDraw.load(ordering: .relaxed) else {
            return
        }

        let bounds = layer.bounds
        let clipBounds = ctx.boundingBoxOfClipPath

        // 横向：略大于裁切区域以重叠绘制方式规避边界缝隙
        // 纵向：全高绘制以避免处理竖直方向上的分片处理
        var backgroundRect = clipBounds
        backgroundRect.origin.y = 0
        backgroundRect.size.height = bounds.height.rounded(.up)
        backgroundRect = backgroundRect.insetBy(dx: -bounds.width / 2, dy: 0)
        backgroundRect.origin.x = max(backgroundRect.origin.x, 0)

        defer {
            debugPrint("zoom \(zoomFactor) background \(backgroundRect) clip \(clipBounds)")
        }

        // 绘制背景
        Self.drawBackgroundInBounds(backgroundRect, in: ctx)

        // 绘制标尺
        Self.drawRulerInBounds(
            CGRect(
                x: backgroundRect.minX,
                y: backgroundRect.maxY - Self.rulerHeight,
                width: backgroundRect.size.width,
                height: Self.rulerHeight
            ),
            clipBounds: bounds /* It should be `bounds`, not `clipBounds`. */,
            zoomFactor: zoomFactor,
            in: ctx
        )

        // 绘制波形
        if let audioClip {
            var waveformRect = clipBounds
            waveformRect.origin.y = 0
            waveformRect.size.height = backgroundRect.size.height - Self.rulerHeight
            waveformRect = waveformRect.insetBy(dx: -Self.waveformBucketWidth, dy: 0)
            waveformRect.origin.x = max(waveformRect.origin.x, 0)

            Self.drawWaveformInBounds(
                waveformRect,
                audioClip: audioClip,
                clipBounds: bounds,
                zoomFactor: zoomFactor,
                in: ctx
            )
        }
    }
}
