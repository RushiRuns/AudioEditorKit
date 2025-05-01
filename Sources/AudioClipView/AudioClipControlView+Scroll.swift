//
//  AudioClipControlView+Scroll.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/14.
//

import AVKit
import Foundation

public extension AudioClipControlView {
    fileprivate static let scrollBaseOffset: CGFloat = 5.0

    func reloadScrollTimerOperation() {
        var newOperation: ScrollOperation?

        newOperation = switch activeAnchor {
        case let .begin(op, _, _), let .end(op, _, _): op
        case .none: nil
        }

        if newOperation == .move {
            newOperation = nil
        }

        if scrollTimerOperation != newOperation {
            scrollTimerOperation = newOperation
            scrollTimerOperationCount = 0
        }
    }

    func reloadScrollTimer() {
        if scrollTimerOperation != nil, scrollTimer == nil {
            scrollTimer = Timer.scheduledTimer(
                timeInterval: 0.1,
                target: self,
                selector: #selector(scrollTimerFired(_:)),
                userInfo: nil,
                repeats: true
            )
            scrollTimerScheduledAt = CACurrentMediaTime()
        } else if scrollTimerOperation == nil, scrollTimer != nil {
            scrollTimer?.invalidate()
            scrollTimer = nil
            scrollTimerScheduledAt = nil
        }
    }

    @objc private func scrollTimerFired(_: Timer) {
        guard let scrollView,
              let scrollTimerScheduledAt, CACurrentMediaTime() - scrollTimerScheduledAt > 0.75,
              let scrollTimerOperation,
              let activeAnchor,
              let player
        else {
            return
        }

        let scrollOffset: CGFloat
        switch scrollTimerOperation {
        case .move:
            scrollOffset = 0.0
        case .forward, .rewind:
            scrollOffset = Self.scrollBaseOffset
        case .fastForward, .fastRewind:
            let multiplier = pow(2, min(CGFloat(scrollTimerOperationCount / 10).rounded(.up), 8))
            scrollOffset = Self.scrollBaseOffset * multiplier // 256x max.
        }

        guard scrollOffset > 0 else {
            return
        }

        let operationScrolled: Bool
        switch scrollTimerOperation {
        case .move:
            operationScrolled = false
        case .forward, .fastForward:
            if case .begin = activeAnchor, !endAnchorBounds.isEmpty {
                // Prevent scrolling when the opposite anchor is at the edge.
                return
            }
            operationScrolled = scrollView.scrollForward(by: scrollOffset)
        case .rewind, .fastRewind:
            if case .end = activeAnchor, !beginAnchorBounds.isEmpty {
                // Prevent scrolling when the opposite anchor is at the edge.
                return
            }
            operationScrolled = scrollView.scrollRewind(by: scrollOffset)
        }

        guard operationScrolled else {
            return
        }

        dispatchAnchorChange(activeAnchor, sync: false)
        player.currentTime = scrollView.currentTimeOffset

        scrollTimerOperationCount += 1
    }
}
