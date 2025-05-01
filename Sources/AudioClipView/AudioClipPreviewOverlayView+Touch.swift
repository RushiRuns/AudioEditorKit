//
//  AudioClipPreviewOverlayView+Touch.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/14.
//

import UIKit

public extension AudioClipPreviewOverlayView {
    static let minimumEditableInterval: TimeInterval = 1.0

    enum Anchor {
        case leading(CGFloat)
        case trailing(CGFloat)
        case indicator

        init?(positionX: CGFloat, view: AudioClipPreviewOverlayView) {
            guard let audioClip = view.audioClip else {
                return nil
            }

            guard audioClip.duration > AudioClipPreviewOverlayView.minimumEditableInterval else {
                return nil
            }

            let underlyingRect = view.bounds.insetBy(
                dx: AudioClipPreviewOverlayView.anchorWidth,
                dy: AudioClipPreviewOverlayView.borderWidth
            )

            let startTime = audioClip.startTime
            let startPositionX = underlyingRect.minX + underlyingRect.width * CGFloat(startTime / audioClip.duration)

            if startPositionX - AudioClipPreviewOverlayView.anchorWidth * 2 ... startPositionX ~= positionX {
                self = .leading(startPositionX - positionX)
                return
            }

            let endTime = audioClip.endTime
            let endPositionX = underlyingRect.minX + underlyingRect.width * CGFloat(endTime / audioClip.duration)

            if endPositionX ... endPositionX + AudioClipPreviewOverlayView.anchorWidth * 2 ~= positionX {
                self = .trailing(positionX - endPositionX)
                return
            }

            if startPositionX ... endPositionX ~= positionX {
                self = .indicator
                return
            }

            return nil
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isEnabled,
              activeAnchor == nil,
              let anyTouch = touches.first,
              anyTouch.tapCount == 1,
              let audioClip,
              audioClip.inProgressEditorIdentifier.value == nil
        else {
            return
        }

        let positionX = anyTouch.location(in: self).x
        activeAnchor = Anchor(positionX: positionX, view: self)

        if let activeAnchor {
            dispatchAnchorChange(activeAnchor, to: positionX)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let activeAnchor,
              let anyTouch = touches.first,
              anyTouch.tapCount == 1
        else {
            return
        }

        let positionX = anyTouch.location(in: self).x
        dispatchAnchorChange(activeAnchor, to: positionX)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        if let activeAnchor,
           let anyTouch = touches.first,
           anyTouch.tapCount <= 1
        {
            let positionX = anyTouch.location(in: self).x
            dispatchAnchorChange(activeAnchor, to: positionX)
        }

        activeAnchor = nil
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        activeAnchor = nil
    }

    private func dispatchAnchorChange(_ anchor: Anchor, to positionX: CGFloat) {
        guard let audioClip else {
            return
        }

        guard audioClip.duration > Self.minimumEditableInterval else {
            return
        }

        let underlyingRect = bounds.insetBy(dx: Self.anchorWidth, dy: Self.borderWidth)
        let realPositionX: CGFloat

        switch anchor {
        case let .leading(diffX):
            realPositionX = min(max(positionX + diffX, underlyingRect.minX), underlyingRect.maxX)
            var newStartTime = audioClip.duration * TimeInterval((realPositionX - underlyingRect.minX) / underlyingRect.width)
            newStartTime = min(max(newStartTime, 0), audioClip.endTime - Self.minimumEditableInterval)
            audioClip.startTime = newStartTime
            syncPlayerTime(to: newStartTime, boundary: true, force: false)

        case let .trailing(diffX):
            realPositionX = min(max(positionX - diffX, underlyingRect.minX), underlyingRect.maxX)
            var newEndTime = audioClip.duration * TimeInterval((realPositionX - underlyingRect.minX) / underlyingRect.width)
            newEndTime = min(max(newEndTime, audioClip.startTime + Self.minimumEditableInterval), audioClip.duration)
            audioClip.endTime = newEndTime
            syncPlayerTime(to: newEndTime, boundary: true, force: false)

        case .indicator:
            realPositionX = min(max(positionX, underlyingRect.minX), underlyingRect.maxX)
            var newCurrentTime = audioClip.duration * TimeInterval((realPositionX - underlyingRect.minX) / underlyingRect.width)
            newCurrentTime = min(newCurrentTime, audioClip.duration)
            syncPlayerTime(to: newCurrentTime, boundary: false, force: true)
        }
    }

    private func syncPlayerTime(to targetTime: TimeInterval, boundary: Bool, force: Bool) {
        guard let player, let audioClip else {
            return
        }

        let isPlaying = player.isPlaying

        if force || !isPlaying {
            let timeRange = boundary ? audioClip.totalTimeRange : audioClip.timeRange
            let currentTime = clamp(targetTime, to: timeRange)

            player.currentTime = currentTime
            if !isPlaying {
                audioClip.currentTime = currentTime
            }
        } else if isPlaying {
            let currentTime = player.currentTime
            let adjustedTime = clamp(currentTime, to: audioClip.timeRange)

            if adjustedTime != currentTime {
                player.currentTime = adjustedTime
            }
        }
    }
}
