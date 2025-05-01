//
//  AudioClipOverlayView+Track.swift
//  TRApp
//
//  Created by Rachel on 12/1/2025.
//

import Combine
import UIKit

public extension AudioClipOverlayView {
    enum TrackMode {
        case followScrollView(Bool)
        case followPlayer
    }

    var shouldAllowUserInteraction: Bool {
        if case .available = viewStateSubject.value,
           case .followScrollView = trackMode
        {
            return true
        }
        return false
    }

    func reloadTrackMode() {
        playerTrackCancellables.forEach { $0.cancel() }
        playerTrackCancellables.removeAll()

        isUserInteractionEnabled = shouldAllowUserInteraction

        if let audioClip {
            if case .followPlayer = trackMode {
                audioClip.$currentTime
                    .removeDuplicates()
                    .receive(on: RunLoop.main)
                    .sink { [weak self] in
                        self?.scrollToTimeOffset($0)
                    }
                    .store(in: &playerTrackCancellables)
            } else {
                audioClip.$currentTime
                    .removeDuplicates()
                    .sink { [weak self] in
                        self?.scrollToTimeOffset($0, conditionally: true)
                    }
                    .store(in: &playerTrackCancellables)
            }
        }

        var isDragging = false
        if case let .followScrollView(dragging) = trackMode {
            isDragging = dragging
        } else {
            isDragging = false
        }

        if isDragging {
            audioClip?.inProgressEditorIdentifier.send(hashValue)
            player?.beginEditing()
        } else {
            player?.endEditing()
            audioClip?.inProgressEditorIdentifier.send(nil)
        }
    }

    // MARK: - Scroll to…

    func scrollToCurrentTime() {
        guard let audioClip, case .available = viewStateSubject.value else {
            return
        }

        scrollToTimeOffset(audioClip.currentTime, conditionally: false)
    }

    func scrollToTimeOffset(_ timeOffset: TimeInterval, conditionally: Bool = false) {
        guard case .available = viewStateSubject.value else {
            return
        }

        if conditionally, let audioClip {
            guard audioClip.inProgressEditorIdentifier.value != hashValue else {
                scrollView.updateContentSizeAndScrollableAreaIfNeeded()
                return
            }
        }

        scrollView.scrollToTimeOffset(timeOffset, animated: false)
    }

    func breakDeceleration() {
        guard case .followScrollView = trackMode else {
            return
        }

        scrollView.breakDeceleration()
    }
}

extension AudioClipOverlayView: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_: UIScrollView) {
        if case let .followScrollView(isDragging) = trackMode, !isDragging {
            trackMode = .followScrollView(true)
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        controlView.setNeedsDisplay()
        if case let .followScrollView(isDragging) = trackMode, isDragging,
           let scrollView = scrollView as? AudioClipScrollView
        {
            player?.currentTime = scrollView.currentTimeOffset
        }
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate, case let .followScrollView(isDragging) = trackMode, isDragging {
            trackMode = .followScrollView(false)
        }
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        if case let .followScrollView(isDragging) = trackMode, isDragging {
            trackMode = .followScrollView(false)
        }
    }
}
