//
//  AudioClipPreviewOverlayView.swift
//  TRApp
//
//  Created by Rachel on 25/12/2024.
//

import AudioClip
import AudioClipPlayer
import Combine
import Foundation
import UIKit

public final class AudioClipPreviewOverlayView: HitTestView {
    public weak var audioClip: AudioClip? {
        didSet {
            reloadAudioClip()
        }
    }

    public weak var player: AudioClipPlayer?
    public var isEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private func reloadAudioClip() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        if let audioClip {
            Publishers
                .CombineLatest3(
                    audioClip.$startTime,
                    audioClip.$endTime,
                    audioClip.$currentTime.removeDuplicates()
                )
                .sink { [weak self] _, _, _ in
                    self?.setNeedsDisplay()
                }
                .store(in: &cancellables)
        }

        setNeedsDisplay()
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    static let anchorWidth: CGFloat = 12.0
    static let borderWidth: CGFloat = 2.0
    static let indicatorWidth: CGFloat = 4.0

    private static let leadingImage: UIImage = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        return UIImage(systemName: "chevron.compact.left", withConfiguration: configuration)!
            .withTintColor(foregroundColor, renderingMode: .alwaysTemplate)
    }()

    private static let trailingImage: UIImage = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        return UIImage(systemName: "chevron.compact.right", withConfiguration: configuration)!
            .withTintColor(foregroundColor, renderingMode: .alwaysTemplate)
    }()

    private static let foregroundColor = UIColor.label
    private static let backgroundColor = UIColor(named: "WarningColor", in: .module, compatibleWith: nil)!
    private static let indicatorColor = UIColor.systemBlue
    private static let backgroundOpacity: CGFloat = 0.2

    override public func draw(_: CGRect) {
        guard let audioClip,
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        guard audioClip.duration > Self.minimumEditableInterval else {
            return
        }

        let underlyingRect = bounds.insetBy(
            dx: Self.anchorWidth,
            dy: Self.borderWidth
        )

        let startPositionX = underlyingRect.minX + underlyingRect.width * CGFloat(audioClip.startTime / audioClip.duration)
        let endPositionX = underlyingRect.minX + underlyingRect.width * CGFloat(audioClip.endTime / audioClip.duration)
        let intervalWidth = underlyingRect.width * CGFloat((audioClip.endTime - audioClip.startTime) / audioClip.duration)

        // draw background
        context.saveGState()
        context.setAlpha(Self.backgroundOpacity)
        context.setFillColor(Self.backgroundColor.cgColor)
        let backgroundRect = CGRect(
            x: startPositionX,
            y: underlyingRect.minY,
            width: intervalWidth,
            height: underlyingRect.height
        )
        context.fill(backgroundRect)
        context.restoreGState()

        // draw borders
        context.saveGState()
        var borderRect: CGRect
        context.setFillColor(Self.backgroundColor.cgColor)
        borderRect = CGRect(
            x: startPositionX,
            y: underlyingRect.minY,
            width: intervalWidth,
            height: Self.borderWidth
        )
        context.fill(borderRect)
        borderRect = CGRect(
            x: startPositionX,
            y: underlyingRect.maxY - Self.borderWidth,
            width: intervalWidth,
            height: Self.borderWidth
        )
        context.fill(borderRect)
        context.restoreGState()

        // draw anchors
        context.saveGState()
        context.setFillColor(Self.backgroundColor.cgColor)
        let leadingAnchorRect = CGRect(
            x: startPositionX - Self.anchorWidth,
            y: underlyingRect.minY,
            width: Self.anchorWidth,
            height: underlyingRect.height
        )
        context.fill(leadingAnchorRect)
        let trailingAnchorRect = CGRect(
            x: endPositionX,
            y: underlyingRect.minY,
            width: Self.anchorWidth,
            height: underlyingRect.height
        )
        context.fill(trailingAnchorRect)
        context.restoreGState()

        // draw foreground
        context.saveGState()
        let imageSize = CGSize(
            width: Self.anchorWidth / 2,
            height: underlyingRect.height / 2
        )
        var imageRect: CGRect
        context.setFillColor(Self.foregroundColor.cgColor)
        imageRect = CGRect(
            x: leadingAnchorRect.midX - imageSize.width / 2,
            y: leadingAnchorRect.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        context.draw(Self.leadingImage.cgImage!, in: imageRect)
        imageRect = CGRect(
            x: trailingAnchorRect.midX - imageSize.width / 2,
            y: trailingAnchorRect.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        context.draw(Self.trailingImage.cgImage!, in: imageRect)
        context.restoreGState()

        // draw indicator
        if endPositionX - Self.indicatorWidth > startPositionX {
            context.saveGState()
            let rangeRect = underlyingRect.insetBy(dx: Self.indicatorWidth / 2, dy: 0)
            let currentPositionX = rangeRect.minX + rangeRect.width * CGFloat(audioClip.currentTime / audioClip.duration)
            let indicatorRect = CGRect(
                x: clamp(
                    currentPositionX - Self.indicatorWidth / 2,
                    to: startPositionX ... endPositionX - Self.indicatorWidth
                ),
                y: rangeRect.minY,
                width: Self.indicatorWidth,
                height: rangeRect.height
            )
            context.setFillColor(Self.indicatorColor.cgColor)
            context.fill(indicatorRect)
            context.restoreGState()
        }
    }

    // MARK: - User Interactions

    var activeAnchor: Anchor? {
        didSet {
            if activeAnchor != nil {
                audioClip?.inProgressEditorIdentifier.send(hashValue)
                player?.beginEditing()
            } else {
                player?.endEditing()
                audioClip?.inProgressEditorIdentifier.send(nil)
            }
        }
    }
}
