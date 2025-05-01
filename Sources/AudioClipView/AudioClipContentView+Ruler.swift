//
//  AudioClipContentView+Ruler.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/29.
//

import UIKit

public extension AudioClipContentView {
    static let rulerColor: UIColor = .tertiarySystemFill
    static let rulerLabelColor: UIColor = .tertiaryLabel
    static let rulerHeight: CGFloat = 32.0

    private static let rulerLineWidth: CGFloat = 0.75
    private static let rulerPrimaryHeight: CGFloat = 10.0
    private static let rulerSecondaryHeight: CGFloat = 5.0
    private static let rulerLabelAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular),
        .foregroundColor: UIColor.tertiaryLabel,
    ]

    private static let defaultPointsPerSecond: CGFloat = 192.0
    private static let unitIntervals: [TimeInterval] = [
        0.25, 0.5, 1.0, 5.0, 15.0, 30.0, 60.0,
    ].reversed()

    static func pointsPerSecond(with zoomFactor: CGFloat) -> CGFloat {
        defaultPointsPerSecond * zoomFactor
    }

    var pointsPerSecond: CGFloat {
        Self.pointsPerSecond(with: zoomFactor)
    }

    static func drawRulerInBounds(
        _ bounds: CGRect,
        clipBounds: CGRect,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        let timeScale = 1.0 / zoomFactor
        if let unitInterval = unitIntervals.first(where: { $0 <= timeScale }) {
            _drawRulerInBounds(
                bounds,
                clipBounds: clipBounds,
                unitInterval: unitInterval,
                zoomFactor: zoomFactor,
                in: ctx
            )
        }
    }

    static func drawAlignedRulerInBounds(
        _ bounds: CGRect,
        alignedTo middleTime: TimeInterval,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        let timeScale = 1.0 / zoomFactor
        if let unitInterval = unitIntervals.first(where: { $0 <= timeScale }) {
            _drawAlignedRulerInBounds(
                bounds,
                alignedTo: middleTime,
                unitInterval: unitInterval,
                zoomFactor: zoomFactor,
                in: ctx
            )
        }
    }

    private static func _drawAlignedRulerInBounds(
        _ bounds: CGRect,
        alignedTo middleTime: TimeInterval,
        unitInterval: TimeInterval,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        defer {
            ctx.restoreGState()
        }

        let pointsPerSecond = Self.pointsPerSecond(with: zoomFactor)
        let unitWidth = unitInterval * pointsPerSecond

        let maximumUnitCountToDraw = (middleTime / unitInterval).rounded(.down)
        let nearestUnitTime = maximumUnitCountToDraw * unitInterval
        let nearestUnitDistance = (middleTime - nearestUnitTime) * pointsPerSecond
        let nearestX = bounds.midX - nearestUnitDistance

        let unitCountToDraw = min((bounds.size.width / unitWidth).rounded(.up), maximumUnitCountToDraw)
        let beginX = nearestX - unitCountToDraw * unitWidth

        ctx.setFillColor(rulerColor.cgColor)
        _drawRulerUnits(
            xRange: beginX ... bounds.maxX,
            y: bounds.maxY - rulerHeight,
            unitWidth: unitWidth,
            in: ctx
        )

        ctx.setFillColor(rulerLabelColor.cgColor)
        ctx.inUIContext {
            _drawRulerLabels(
                xRange: beginX ... bounds.maxX,
                minY: bounds.maxY - rulerHeight + rulerPrimaryHeight,
                fractionalSeconds: unitInterval < 1.0,
                beginTime: nearestUnitTime - unitCountToDraw * unitInterval,
                unitInterval: unitInterval,
                unitWidth: unitWidth,
                in: ctx
            )
        }
    }

    private static func _drawRulerInBounds(
        _ bounds: CGRect,
        clipBounds: CGRect,
        unitInterval: TimeInterval,
        zoomFactor: CGFloat,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        defer {
            ctx.restoreGState()
        }

        let pointsPerSecond = Self.pointsPerSecond(with: zoomFactor)
        let unitWidth = unitInterval * pointsPerSecond

        let beginX = bounds.minX - bounds.minX.truncatingRemainder(dividingBy: unitWidth)

        ctx.setFillColor(rulerColor.cgColor)
        _drawRulerUnits(
            xRange: beginX ... bounds.maxX,
            y: bounds.minY,
            unitWidth: unitWidth,
            in: ctx
        )

        ctx.setFillColor(rulerLabelColor.cgColor)
        ctx.inUIContext {
            _drawRulerLabels(
                xRange: beginX ... bounds.maxX,
                clipRange: clipBounds.minX ... clipBounds.maxX,
                minY: bounds.minY + rulerPrimaryHeight,
                fractionalSeconds: unitInterval < 1.0,
                beginTime: beginX / pointsPerSecond,
                unitInterval: unitInterval,
                unitWidth: unitWidth,
                in: ctx
            )
        }
    }

    private static func _drawRulerUnits(
        xRange: ClosedRange<CGFloat>,
        y: CGFloat,
        unitWidth: CGFloat,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        defer {
            ctx.restoreGState()
        }

        var currentX = xRange.lowerBound
        while currentX < xRange.upperBound {
            let primaryUnit = CGRect(
                x: currentX,
                y: y,
                width: rulerLineWidth,
                height: rulerPrimaryHeight
            )
            ctx.fill(primaryUnit)

            for i in 1 ... 3 {
                let secondaryRect = CGRect(
                    x: currentX + CGFloat(i) * unitWidth / 4,
                    y: y,
                    width: rulerLineWidth,
                    height: rulerSecondaryHeight
                )
                ctx.fill(secondaryRect)
            }

            currentX += unitWidth
        }
    }

    private static func _drawRulerLabels(
        xRange: ClosedRange<CGFloat>,
        clipRange: ClosedRange<CGFloat>? = nil,
        minY: CGFloat,
        fractionalSeconds: Bool,
        beginTime: TimeInterval,
        unitInterval: TimeInterval,
        unitWidth: CGFloat,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        defer {
            ctx.restoreGState()
        }

        var currentX = xRange.lowerBound
        var currentTime = beginTime
        while currentX < xRange.upperBound {
            let unitLabel = unitLabel(at: currentTime, fractionalSeconds: fractionalSeconds)
            if !unitLabel.isEmpty {
                let labelSize = unitLabel.size(withAttributes: rulerLabelAttributes)
                let labelRect = CGRect(
                    x: currentX,
                    y: minY,
                    width: labelSize.width,
                    height: labelSize.height
                )

                if let clipRange, labelRect.maxX > clipRange.upperBound {
                    break
                }

                unitLabel.draw(in: labelRect, withAttributes: rulerLabelAttributes)
            }

            currentX += unitWidth
            currentTime += unitInterval
        }
    }

    private static func unitLabel(
        at preciseTime: TimeInterval,
        fractionalSeconds: Bool
    ) -> String {
        guard preciseTime >= 0 else {
            return ""
        }

        let timeString = preciseTime
            .preciseDurationString(includingMilliseconds: fractionalSeconds)

        if fractionalSeconds, preciseTime < 60, timeString.hasPrefix("00:") {
            return String(timeString.dropFirst(3))
        }

        return timeString
    }
}

private extension CGContext {
    func inUIContext(_ block: () -> Void) {
        UIGraphicsPushContext(self)
        defer {
            UIGraphicsPopContext()
        }
        block()
    }
}
