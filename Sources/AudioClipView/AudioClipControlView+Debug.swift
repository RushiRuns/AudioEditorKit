//
//  AudioClipControlView+Debug.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/15.
//

import CoreGraphics
import UIKit

#if DEBUG
    public extension AudioClipControlView {
        func drawDebugControlMask(in ctx: CGContext) {
            var debugRect: CGRect

            debugRect = CGRect(
                x: 0,
                y: 0,
                width: bounds.width * 0.125,
                height: bounds.height
            )

            Self.drawDebugControlMaskInBounds(debugRect, opacity: Self.backgroundOpacity * 2, in: ctx)

            debugRect = CGRect(
                x: bounds.width * 0.125,
                y: 0,
                width: bounds.width * 0.125,
                height: bounds.height
            )

            Self.drawDebugControlMaskInBounds(debugRect, opacity: Self.backgroundOpacity, in: ctx)

            debugRect = CGRect(
                x: bounds.width * 0.75,
                y: 0,
                width: bounds.width * 0.125,
                height: bounds.height
            )

            Self.drawDebugControlMaskInBounds(debugRect, opacity: Self.backgroundOpacity, in: ctx)

            debugRect = CGRect(
                x: bounds.width * 0.875,
                y: 0,
                width: bounds.width * 0.125,
                height: bounds.height
            )

            Self.drawDebugControlMaskInBounds(debugRect, opacity: Self.backgroundOpacity * 2, in: ctx)
        }

        static func drawAnchorControlMaskInBounds(_ bounds: CGRect, in ctx: CGContext) {
            guard !bounds.isEmpty else {
                return
            }

            ctx.saveGState()
            ctx.setAlpha(backgroundOpacity)
            ctx.setFillColor(anchorControlColor.cgColor)
            ctx.fill(bounds)
            ctx.restoreGState()
        }

        fileprivate static func drawDebugControlMaskInBounds(_ bounds: CGRect, opacity: CGFloat, in ctx: CGContext) {
            guard !bounds.isEmpty else {
                return
            }

            ctx.saveGState()
            ctx.setAlpha(opacity)
            ctx.setFillColor(UIColor.red.cgColor)
            ctx.fill(bounds)
            ctx.restoreGState()
        }
    }
#endif
