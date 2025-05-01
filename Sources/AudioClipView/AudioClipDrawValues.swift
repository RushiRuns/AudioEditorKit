//
//  AudioClipDrawValues.swift
//  TRApp
//
//  Created by Rachel on 8/1/2025.
//

import CoreFoundation

public struct AudioClipDrawValues {
    public let alignedOffsetX: CGFloat
    public let contentOffsetX: CGFloat
    public let contentWidth: CGFloat
    public let zoomFactor: CGFloat
    public var pinchFactor: CGFloat

    public init(
        alignedOffsetX: CGFloat = 0,
        contentOffsetX: CGFloat = 0,
        contentWidth: CGFloat = 0,
        zoomFactor: CGFloat = 1.0,
        pinchFactor: CGFloat = 1.0
    ) {
        self.alignedOffsetX = alignedOffsetX
        self.contentOffsetX = contentOffsetX
        self.contentWidth = contentWidth
        self.zoomFactor = zoomFactor
        self.pinchFactor = pinchFactor
    }
}
