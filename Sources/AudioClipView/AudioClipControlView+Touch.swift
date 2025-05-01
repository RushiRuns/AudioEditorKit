//
//  AudioClipControlView+Touch.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/14.
//

import UIKit

public extension AudioClipControlView {
    override func hitTest(_ point: CGPoint, with _: UIEvent?) -> UIView? {
        if anchorAtOffsetX(point.x) != nil {
            self
        } else {
            nil
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard activeAnchor == nil,
              let anyTouch = touches.first,
              anyTouch.tapCount == 1,
              let audioClip,
              audioClip.inProgressEditorIdentifier.value == nil
        else {
            return
        }

        let positionX = anyTouch.location(in: self).x
        activeAnchor = anchorAtOffsetX(positionX)

        if let activeAnchor {
            dispatchAnchorChange(activeAnchor, sync: false)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let anchor = activeAnchor,
              let anyTouch = touches.first,
              anyTouch.tapCount == 1
        else {
            return
        }

        let positionX = anyTouch.location(in: self).x
        activeAnchor = moveAnchor(anchor, to: positionX)

        if let activeAnchor {
            dispatchAnchorChange(activeAnchor, sync: false)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        if let anchor = activeAnchor,
           let anyTouch = touches.first,
           anyTouch.tapCount <= 1
        {
            let positionX = anyTouch.location(in: self).x
            activeAnchor = moveAnchor(anchor, to: positionX)

            if let activeAnchor {
                dispatchAnchorChange(activeAnchor, sync: true)
            }
        }

        activeAnchor = nil
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        activeAnchor = nil
    }
}

extension AudioClipControlView {
    enum ScrollOperation {
        case move
        case forward
        case rewind
        case fastForward
        case fastRewind
    }

    private func operationAtOffsetX(_ offsetX: CGFloat) -> ScrollOperation {
        if bounds.minX ... bounds.minX + bounds.width * 0.125 ~= offsetX {
            .fastRewind
        } else if bounds.minX + bounds.width * 0.125 ... bounds.minX + bounds.width * 0.25 ~= offsetX {
            .rewind
        } else if bounds.minX + bounds.width * 0.75 ... bounds.minX + bounds.width * 0.875 ~= offsetX {
            .forward
        } else if bounds.minX + bounds.width * 0.875 ... bounds.maxX ~= offsetX {
            .fastForward
        } else {
            .move
        }
    }
}

extension AudioClipControlView {
    enum Anchor {
        case begin(ScrollOperation, offsetX: CGFloat, diffX: CGFloat)
        case end(ScrollOperation, offsetX: CGFloat, diffX: CGFloat)
    }

    private func anchorAtOffsetX(_ offsetX: CGFloat) -> Anchor? {
        if beginAnchorBounds.contains(CGPoint(x: offsetX, y: bounds.midY)) {
            .begin(.move, offsetX: offsetX, diffX: offsetX - beginAnchorBounds.midX)
        } else if endAnchorBounds.contains(CGPoint(x: offsetX, y: bounds.midY)) {
            .end(.move, offsetX: offsetX, diffX: offsetX - endAnchorBounds.midX)
        } else {
            nil
        }
    }

    private func moveAnchor(_ anchor: Anchor, to offsetX: CGFloat) -> Anchor {
        let newOperation = operationAtOffsetX(offsetX)
        return switch anchor {
        case let .begin(prevOperation, prevX, diffX):
            switch prevOperation {
            case .move:
                .begin(newOperation, offsetX: offsetX, diffX: diffX)
            case .rewind, .fastRewind:
                if offsetX > prevX {
                    .begin(.move, offsetX: offsetX, diffX: diffX)
                } else {
                    .begin(newOperation, offsetX: offsetX, diffX: diffX)
                }
            case .forward, .fastForward:
                if offsetX < prevX {
                    .begin(.move, offsetX: offsetX, diffX: diffX)
                } else {
                    .begin(newOperation, offsetX: offsetX, diffX: diffX)
                }
            }
        case let .end(prevOperation, prevX, diffX):
            switch prevOperation {
            case .move:
                .end(newOperation, offsetX: offsetX, diffX: diffX)
            case .rewind, .fastRewind:
                if offsetX > prevX {
                    .end(.move, offsetX: offsetX, diffX: diffX)
                } else {
                    .end(newOperation, offsetX: offsetX, diffX: diffX)
                }
            case .forward, .fastForward:
                if offsetX < prevX {
                    .end(.move, offsetX: offsetX, diffX: diffX)
                } else {
                    .end(newOperation, offsetX: offsetX, diffX: diffX)
                }
            }
        }
    }
}

extension AudioClipControlView {
    static let minimumEditableInterval: TimeInterval = 1.0

    func dispatchAnchorChange(_ anchor: Anchor, sync: Bool) {
        guard let audioClip, let contentView else {
            return
        }

        guard audioClip.duration > Self.minimumEditableInterval else {
            return
        }

        let anchorPoint = switch anchor {
        case let .begin(_, offsetX, diffX), let .end(_, offsetX, diffX):
            CGPoint(x: offsetX - diffX, y: bounds.midY)
        }

        let shouldSync: Bool
        let contentPoint = convert(anchorPoint, to: contentView)
        let targetTime: TimeInterval = clamp(
            contentPoint.x / contentView.backgroundBounds.width * audioClip.duration, to: audioClip.totalTimeRange
        )

        switch anchor {
        case .begin:
            audioClip.startTime = min(max(targetTime, 0), audioClip.endTime - Self.minimumEditableInterval)
            shouldSync = !beginAnchorBounds.isEmpty && beginAnchorBounds.midX > bounds.midX && anchorPoint.x > bounds.midX
        case .end:
            audioClip.endTime = min(max(targetTime, audioClip.startTime + Self.minimumEditableInterval), audioClip.duration)
            shouldSync = !endAnchorBounds.isEmpty && endAnchorBounds.midX < bounds.midX && anchorPoint.x < bounds.midX
        }

        if sync, shouldSync, let player {
            player.currentTime = clamp(targetTime, to: audioClip.timeRange)
        }
    }
}
