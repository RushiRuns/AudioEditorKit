//
//  AudioClipControlView.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/7.
//

import AudioClip
import AudioClipPlayer
import Combine
import UIKit

public final class AudioClipControlView: UIView {
    weak var audioClip: AudioClip? {
        didSet {
            reloadAudioClip()
        }
    }

    weak var contentView: AudioClipContentView?
    weak var scrollView: AudioClipScrollView?
    weak var player: AudioClipPlayer?

    private var cancellables: Set<AnyCancellable> = []

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
        backgroundColor = .clear
    }

    private func reloadAudioClip() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        if let audioClip {
            Publishers
                .CombineLatest3(
                    audioClip.$startTime,
                    audioClip.$endTime,
                    audioClip.$currentTime.removeDuplicates()
                )
                .sink { [weak self] _, _, _ in
                    self?.setNeedsDisplay()
                }
                .store(in: &cancellables)
        }

        setNeedsDisplay()
    }

    static let anchorControlColor = UIColor(named: "FailureColor", in: .module, compatibleWith: nil)!
    static let backgroundColor = UIColor(named: "WarningColor", in: .module, compatibleWith: nil)!
    static let indicatorColor = UIColor.systemBlue

    static let anchorCircleSpacing: CGFloat = 9.0
    static let anchorControlWidth: CGFloat = 25.0
    static let anchorLineWidth: CGFloat = 1.0
    static let anchorCircleRadius: CGFloat = 3.5
    static let backgroundOpacity: CGFloat = 0.2

    private(set) var beginAnchorBounds: CGRect = .zero
    private(set) var endAnchorBounds: CGRect = .zero

    override public func draw(_: CGRect) {
        guard let audioClip,
              let contentView,
              let ctx = UIGraphicsGetCurrentContext()
        else {
            return
        }

        let syncRect: CGRect = {
            let startX = contentView.backgroundBounds.width * CGFloat(audioClip.startTime / audioClip.duration)
            let endX = contentView.backgroundBounds.width * CGFloat(audioClip.endTime / audioClip.duration)
            return convert(CGRect(
                x: startX,
                y: 0,
                width: endX - startX,
                height: contentView.backgroundBounds.height
            ), from: contentView)
        }()

        let enlargedRect = bounds.insetBy(dx: -Self.anchorCircleRadius, dy: 0)
        guard syncRect.intersects(enlargedRect) else {
            return
        }

        // draw background
        let backgroundRect = syncRect.intersection(bounds)
        Self.drawControlMaskInBounds(backgroundRect, in: ctx)

        // draw center indicator
        let shouldDrawCenterIndicator = (
            !backgroundRect.isEmpty &&
                backgroundRect.minX + 1.0 < bounds.midX &&
                bounds.midX < backgroundRect.maxX - 1.0
        )
        if shouldDrawCenterIndicator {
            Self.drawAnchor(
                x: bounds.midX,
                yRange: backgroundRect.minY ... backgroundRect.maxY,
                color: Self.indicatorColor.cgColor,
                in: ctx
            )
        }

        // draw anchors
        let anchorRangeX = enlargedRect.minX ... enlargedRect.maxX
        let anchorRect = syncRect.intersection(enlargedRect)
        let shouldDrawBeginAnchor = anchorRangeX ~= syncRect.minX
        if shouldDrawBeginAnchor {
            beginAnchorBounds = CGRect(
                x: anchorRect.minX - Self.anchorControlWidth / 2,
                y: syncRect.minY - Self.anchorCircleRadius * 2,
                width: Self.anchorControlWidth,
                height: syncRect.height + Self.anchorCircleRadius * 4
            )
            #if DEBUG
                Self.drawAnchorControlMaskInBounds(beginAnchorBounds, in: ctx)
            #endif
            Self.drawAnchor(
                x: anchorRect.minX,
                yRange: syncRect.minY ... syncRect.maxY,
                color: Self.backgroundColor.cgColor,
                in: ctx
            )
        } else {
            beginAnchorBounds = .zero
        }
        let shouldDrawEndAnchor = anchorRangeX ~= syncRect.maxX
        if shouldDrawEndAnchor {
            endAnchorBounds = CGRect(
                x: anchorRect.maxX - Self.anchorControlWidth / 2,
                y: syncRect.minY - Self.anchorCircleRadius * 2,
                width: Self.anchorControlWidth,
                height: syncRect.height + Self.anchorCircleRadius * 4
            )
            #if DEBUG
                Self.drawAnchorControlMaskInBounds(endAnchorBounds, in: ctx)
            #endif
            Self.drawAnchor(
                x: anchorRect.maxX,
                yRange: syncRect.minY ... syncRect.maxY,
                color: Self.backgroundColor.cgColor,
                in: ctx
            )
        } else {
            endAnchorBounds = .zero
        }

        #if DEBUG
            drawDebugControlMask(in: ctx)
        #endif
    }

    static func drawAnchor(
        x: CGFloat,
        yRange: ClosedRange<CGFloat>,
        color: CGColor,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        ctx.setLineWidth(anchorLineWidth)
        ctx.setFillColor(color)
        ctx.setStrokeColor(color)

        ctx.move(to: CGPoint(
            x: x,
            y: yRange.lowerBound
        ))

        ctx.addLine(to: CGPoint(
            x: x,
            y: yRange.upperBound
        ))

        ctx.strokePath()

        ctx.addArc(
            center: CGPoint(
                x: x,
                y: yRange.lowerBound - anchorCircleRadius
            ),
            radius: anchorCircleRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )

        ctx.fillPath()

        ctx.addArc(
            center: CGPoint(
                x: x,
                y: yRange.upperBound + anchorCircleRadius
            ),
            radius: anchorCircleRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )

        ctx.fillPath()

        ctx.restoreGState()
    }

    static func drawControlMaskInBounds(_ bounds: CGRect, in ctx: CGContext) {
        guard !bounds.isEmpty else {
            return
        }

        ctx.saveGState()
        ctx.setAlpha(backgroundOpacity)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(bounds)
        ctx.restoreGState()
    }

    // MARK: - User Interactions

    var activeAnchor: Anchor? {
        didSet {
            if activeAnchor != nil {
                audioClip?.inProgressEditorIdentifier.send(hashValue)
                player?.beginEditing()
            } else {
                player?.endEditing()
                audioClip?.inProgressEditorIdentifier.send(nil)
            }
            reloadScrollTimerOperation()
        }
    }

    var scrollTimer: Timer?
    var scrollTimerScheduledAt: TimeInterval?
    var scrollTimerOperationCount: Int = 0
    var scrollTimerOperation: ScrollOperation? {
        didSet {
            reloadScrollTimer()
        }
    }
}
