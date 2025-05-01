//
//  AudioClipOverlayView+Zoom.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/2.
//

import UIKit

public extension AudioClipOverlayView {
    static let maximumZoomScale: CGFloat = 4.0 // 1/4 second
    static let minimumZoomScale: CGFloat = 0.00416666 // 240 seconds
    static let initialZoomScale: CGFloat = 1.0

    func updateZoomScale(_ zoomScale: CGFloat) {
        audioClip?.zoomFactor = zoomScale
        scrollView.contentZoomFactor = zoomScale
    }

    func updatePinchScale(_ pinchScale: CGFloat) {
        guard case .pinching = viewStateSubject.value else {
            return
        }

        var drawValues = beginDrawValues
        drawValues.pinchFactor = pinchScale
        pinchView.drawValues = drawValues
    }

    static func suggestedZoomScale(for duration: TimeInterval) -> CGFloat {
        let zoomScale = CGFloat(24.0 / duration)
        return max(min(zoomScale, maximumZoomScale), minimumZoomScale)
    }
}
