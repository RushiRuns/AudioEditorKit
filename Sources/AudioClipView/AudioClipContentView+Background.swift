//
//  AudioClipContentView+Background.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/6.
//

import QuartzCore
import UIKit

public extension AudioClipContentView {
    var backgroundBounds: CGRect {
        CGRect(origin: bounds.origin, size: CGSize(
            width: bounds.size.width,
            height: bounds.size.height - Self.rulerHeight
        ))
    }

    static let backgroundColor: UIColor = .quaternarySystemFill

    static func drawBackgroundInBounds(
        _ bounds: CGRect,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        let backgroundHeight = bounds.size.height - rulerHeight
        let backgroundRect = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.size.width,
            height: backgroundHeight
        )
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(backgroundRect)
        ctx.restoreGState()
    }
}
