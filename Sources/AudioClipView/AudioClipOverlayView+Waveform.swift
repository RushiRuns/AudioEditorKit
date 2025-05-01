//
//  AudioClipOverlayView+Waveform.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/2.
//

import Combine
import UIKit

public extension AudioClipOverlayView {
    func reloadWaveformWithPinchScale(_ pinchScale: CGFloat, isInitial: Bool) {
        viewStateSubject.send(.loading(isInitial: isInitial))

        let pinchStatus = pinchChanged(pinchScale)
        let adjustedOffsetX: CGFloat = (
            scrollView.contentInsetLeft + beginDrawValues.contentOffsetX
        ) * pinchStatus.pinchScale - scrollView.contentInsetLeft

        // 因为方案修改，暂时没有什么需要在捏合结束后进行计算的
        // 但是如果波形解码稍慢一些，即 aac 时长接近上限且缩放到最小，就有可能出现波形割裂的问题
        // 捏合结束后冻屏，后续可以在这里插入一些异步的优化代码

        _taskCompleted(
            offsetX: adjustedOffsetX,
            zoomFactor: pinchStatus.zoomScale,
            isInitial: isInitial
        )
    }

    private func _taskInterrupted(_: Error) {
        guard case .loading = viewStateSubject.value else {
            return
        }

        viewStateSubject.send(.failed)
    }

    private func _taskCompleted(
        offsetX: CGFloat,
        zoomFactor _: CGFloat,
        isInitial: Bool
    ) {
        guard case .loading = viewStateSubject.value else {
            return
        }

        viewStateSubject.send(.loaded(isInitial: isInitial))

        scrollView.contentOffsetX = offsetX
        if isInitial {
            if let audioClip, audioClip.currentTime > 1e-3 {
                scrollView.setNeedsScrollToTimeOffset(audioClip.currentTime)
            } else {
                scrollView.setNeedsScrollToStart()
            }
        }

        scrollView.setNeedsUpdateContentSizeAndScrollableArea()
        scrollView.updateContentSizeAndScrollableAreaIfNeeded()
    }
}
