//
//  AudioClipOverlayView+Pinch.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/2.
//

import UIKit

public extension AudioClipOverlayView {
    func _initializePinchGesture() {
        _pinchEnded(1.0, isInitial: true)
    }

    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            _pinchGestureBegan()
        case .changed:
            _pinchGestureChanged(gesture.scale)
        case .ended, .cancelled, .failed:
            _pinchEnded(gesture.scale)
        default: break
        }
    }

    private func _pinchGestureBegan() {
        _pinchBegan()
    }

    private func _pinchBegan() {
        guard case .available = viewStateSubject.value else {
            return
        }

        viewStateSubject.send(.pinching)

        let pinchFactor = 1.0
        beginDrawValues = AudioClipDrawValues(
            alignedOffsetX: scrollView.alignedOffsetX,
            contentOffsetX: scrollView.contentOffsetX,
            contentWidth: scrollView.contentWidth,
            zoomFactor: zoomScaleSubject.value,
            pinchFactor: pinchFactor
        )

        pinchChanged(pinchFactor)
    }

    private func _pinchGestureChanged(_ gestureScale: CGFloat) {
        guard case .pinching = viewStateSubject.value else {
            return
        }

        pinchChanged(gestureScale)
    }

    @discardableResult
    func pinchChanged(_ gestureScale: CGFloat) -> (zoomScale: CGFloat, pinchScale: CGFloat) {
        let newZoomScale = max(Self.minimumZoomScale, min(beginDrawValues.zoomFactor * gestureScale, Self.maximumZoomScale))
        zoomScaleSubject.send(newZoomScale)

        let newPinchScale = newZoomScale / beginDrawValues.zoomFactor
        pinchScaleSubject.send(newPinchScale)

        return (newZoomScale, newPinchScale)
    }

    private func _pinchGestureEnded(_ gestureScale: CGFloat) {
        _pinchEnded(gestureScale)
    }

    private func _pinchEnded(_ gestureScale: CGFloat, isInitial: Bool = false) {
        if isInitial {
            guard viewStateSubject.value.isReadyOrFailed else {
                return
            }
        } else {
            guard case .pinching = viewStateSubject.value else {
                return
            }
        }

        reloadWaveformWithPinchScale(gestureScale, isInitial: isInitial)
    }
}
