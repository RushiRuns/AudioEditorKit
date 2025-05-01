//
//  AudioClipScrollView.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/29.
//

import Atomics
import AudioClip
import Combine
import UIKit

public final class AudioClipScrollView: UIScrollView {
    private static let tileMultiplier: CGFloat = 4.0

    // MARK: - Subviews

    private let isAllowedToDrawContent = ManagedAtomic<Bool>(false)
    private(set) lazy var contentView = AudioClipContentView(isAllowedToDraw: isAllowedToDrawContent)

    // MARK: - Initialization

    init() {
        super.init(frame: .zero)
        _commonInit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func _commonInit() {
        _setupCommonAttributes()
        addSubview(contentView)
    }

    private func _setupCommonAttributes() {
        backgroundColor = .clear
        automaticallyAdjustsScrollIndicatorInsets = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .normal
        isScrollEnabled = true
        alwaysBounceHorizontal = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        scrollsToTop = false
    }

    // MARK: - Public

    var alignedOffsetX: CGFloat {
        get { contentOffset.x + scrollableArea.minX }
        set { contentOffset = CGPoint(x: newValue - scrollableArea.minX, y: 0) }
    }

    func setAlignedOffsetX(_ newValue: CGFloat, animated: Bool) {
        setContentOffset(CGPoint(x: newValue - scrollableArea.minX, y: 0), animated: animated)
    }

    weak var audioClip: AudioClip? {
        didSet {
            contentView.audioClip = audioClip
        }
    }

    weak var controlView: AudioClipControlView? {
        didSet {
            controlView?.contentView = contentView
        }
    }

    var contentInsetLeft: CGFloat {
        get { contentInset.left }
        set { contentInset.left = newValue }
    }

    var contentOffsetX: CGFloat {
        get { contentOffset.x }
        set { contentOffset.x = newValue }
    }

    var contentWidth: CGFloat {
        contentView.intrinsicContentSize.width
    }

    var contentZoomFactor: CGFloat {
        get { contentView.zoomFactor }
        set { contentView.zoomFactor = newValue }
    }

    var isContentHidden: Bool {
        get { contentView.isHidden }
        set { contentView.isHidden = newValue }
    }

    func blockContentDrawing() {
        isAllowedToDrawContent.store(false, ordering: .relaxed)
    }

    func unblockContentDrawing() {
        if !isAllowedToDrawContent.exchange(true, ordering: .relaxed) {
            contentView.setNeedsDisplay()
        }
    }

    func setNeedsScrollToStart() {
        shouldScrollToStart = true
    }

    func setNeedsScrollToTimeOffset(_ timeOffset: TimeInterval) {
        shouldScrollToTimeOffset = timeOffset
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()

        reloadContentFrame()

        if shouldScrollToStart == true {
            shouldScrollToStart = nil
            scrollToStart(animated: false)
        }

        if let timeOffset = shouldScrollToTimeOffset {
            shouldScrollToTimeOffset = nil
            scrollToTimeOffset(timeOffset, animated: false)
        }
    }

    private var previousContentOffsetX: CGFloat?
    private var previousContentWidth: CGFloat?

    private var previousBoundWidth: CGFloat?
    private var previousBoundHeight: CGFloat?

    private func reloadContentFrame() {
        var shouldUpdateContentFrame = false

        let contentOffsetX = -scrollableArea.minX
        if previousContentOffsetX != contentOffsetX {
            previousContentOffsetX = contentOffsetX
            shouldUpdateContentFrame = true
        }

        let contentWidth = contentWidth
        if previousContentWidth != contentWidth {
            previousContentWidth = contentWidth
            shouldUpdateContentFrame = true
        }

        let boundWidth = bounds.size.width
        if previousBoundWidth != boundWidth {
            previousBoundWidth = boundWidth
            contentInset = .init(top: 0, left: bounds.size.width / 2, bottom: 0, right: bounds.size.width / 2)
        }

        let boundHeight = bounds.size.height
        if previousBoundHeight != boundHeight {
            previousBoundHeight = boundHeight

            if let screenScale = window?.windowScene?.screen.scale {
                contentView.tiledLayer.tileSize = CGSize(
                    width: Self.tileMultiplier * bounds.size.width * screenScale,
                    height: bounds.size.height * screenScale
                )
            }

            shouldUpdateContentFrame = true
        }

        if shouldUpdateContentFrame {
            contentView.frame = CGRect(
                origin: CGPoint(x: contentOffsetX, y: 0),
                size: CGSize(width: contentWidth, height: bounds.size.height)
            )

            contentView.setNeedsDisplay()
            controlView?.setNeedsDisplay()
        }
    }

    // MARK: - Scrollable Area

    private var cancellables: Set<AnyCancellable> = []
    private var scrollableArea: CGRect = .zero
    private var shouldUpdateContentSizeAndScrollableArea = true

    func setNeedsUpdateContentSizeAndScrollableArea() {
        shouldUpdateContentSizeAndScrollableArea = true
    }

    func updateContentSizeAndScrollableAreaIfNeeded() {
        guard shouldUpdateContentSizeAndScrollableArea else {
            return
        }

        shouldUpdateContentSizeAndScrollableArea = false

        let newScrollableArea: CGRect = if let audioClip {
            CGRect(
                x: audioClip.startTime * (contentWidth / audioClip.duration),
                y: 0,
                width: (audioClip.endTime - audioClip.startTime) * (contentWidth / audioClip.duration),
                height: bounds.height
            )
        } else {
            .zero
        }

        if scrollableArea != newScrollableArea {
            scrollableArea = newScrollableArea
            contentSize = scrollableArea.size
            setNeedsLayout()

            print(#fileID, "update scrollable area")
        }
    }

    // MARK: - Scroll to…

    var currentTimeOffset: TimeInterval {
        guard let audioClip else {
            return 0.0
        }

        let offsetX = alignedOffsetX + contentInsetLeft
        let timeOffset = TimeInterval(offsetX / contentWidth * audioClip.duration)
        return clamp(timeOffset, to: audioClip.totalTimeRange)
    }

    private var shouldScrollToStart: Bool? {
        didSet {
            setNeedsLayout()
        }
    }

    private var shouldScrollToTimeOffset: TimeInterval? {
        didSet {
            setNeedsLayout()
        }
    }

    private func scrollToStart(animated: Bool) {
        setContentOffset(CGPoint(x: -contentInsetLeft, y: 0), animated: animated)
    }

    func scrollToTimeOffset(_ timeOffset: TimeInterval, animated: Bool) {
        guard let audioClip else {
            return
        }

        updateContentSizeAndScrollableAreaIfNeeded()
        let fraction = clamp(timeOffset / audioClip.duration, to: 0 ... 1)
        let offsetX = CGFloat(fraction * contentWidth)
        setAlignedOffsetX(offsetX - contentInsetLeft, animated: animated)
    }

    @discardableResult
    func scrollForward(by offset: CGFloat) -> Bool {
        var offsetX = alignedOffsetX
        if offsetX + bounds.width < contentWidth {
            updateContentSizeAndScrollableAreaIfNeeded()
            offsetX += offset
            alignedOffsetX = offsetX
            return true
        }
        return false
    }

    @discardableResult
    func scrollRewind(by offset: CGFloat) -> Bool {
        var offsetX = alignedOffsetX
        if offsetX > 0 {
            updateContentSizeAndScrollableAreaIfNeeded()
            offsetX -= offset
            alignedOffsetX = offsetX
            return true
        }
        return false
    }

    func breakDeceleration() {
        if isDecelerating {
            setContentOffset(contentOffset, animated: false)
        }
    }
}
