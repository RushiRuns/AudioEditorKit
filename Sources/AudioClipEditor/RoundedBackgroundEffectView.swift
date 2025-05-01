//
//  RoundedBackgroundEffectView.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/16.
//

import UIKit

private class CircleEffectView: UIView {
    override func draw(_ rect: CGRect) {
        UIColor.quaternarySystemFill.setFill()
        UIBezierPath(
            arcCenter: CGPoint(x: rect.width / 2, y: rect.height / 2),
            radius: rect.width / 2,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).fill()
    }
}

public final class RoundedBackgroundEffectView: UIView {
    var isHighlighted: Bool = false {
        didSet {
            reloadCircleView(highlighted: isHighlighted)
        }
    }

    private var previousIsHighlighted: Bool = false
    private static let highlightedScale: CGFloat = 1.5

    private lazy var circleInView: CircleEffectView = {
        let view = CircleEffectView()
        view.backgroundColor = .clear
        view.transform = .identity.scaledBy(x: Self.highlightedScale, y: Self.highlightedScale)
        view.isHidden = true
        view.alpha = 0
        return view
    }()

    private lazy var circleOutView: CircleEffectView = {
        let view = CircleEffectView()
        view.backgroundColor = .clear
        view.transform = .identity.scaledBy(x: 1 / Self.highlightedScale, y: 1 / Self.highlightedScale)
        view.isHidden = true
        view.alpha = 0
        return view
    }()

    override public func awakeFromNib() {
        super.awakeFromNib()
        insertSubview(circleInView, at: 0)
        insertSubview(circleOutView, at: 0)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let inSideLength = min(bounds.width, bounds.height)
        circleInView.frame = CGRect(
            x: (bounds.width - inSideLength) / 2,
            y: (bounds.height - inSideLength) / 2,
            width: inSideLength,
            height: inSideLength
        )
        let outSideLength = inSideLength * Self.highlightedScale
        circleOutView.frame = CGRect(
            x: (bounds.width - outSideLength) / 2,
            y: (bounds.height - outSideLength) / 2,
            width: outSideLength,
            height: outSideLength
        )
    }

    private func reloadCircleView(highlighted: Bool) {
        if previousIsHighlighted != highlighted {
            if highlighted {
                circleInView.isHidden = false
                circleInView.transform = .identity
                circleInView.alpha = 1.0
                circleOutView.isHidden = true
                circleOutView.transform = .identity.scaledBy(x: 1 / Self.highlightedScale, y: 1 / Self.highlightedScale)
                circleOutView.alpha = 1.0
            } else {
                circleInView.isHidden = true
                circleInView.transform = .identity.scaledBy(x: Self.highlightedScale, y: Self.highlightedScale)
                circleInView.alpha = 0.0
                circleOutView.isHidden = false
                circleOutView.transform = .identity
                circleOutView.alpha = 0.0
            }
            previousIsHighlighted = highlighted
        }
    }
}
