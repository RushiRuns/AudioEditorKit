//
//  ProgressHUDManager.swift
//  TRApp
//
//  Created by Lessica on 2024/6/3.
//

import Foundation
import ProgressHUD
import UIKit

public final class ProgressHUDManager {
    private init() {}

    private weak static var hoverView: UIView?

    private static func showHoverView(in view: UIView) {
        let window = view.window

        if let window {
            let view = UIView(frame: window.bounds)
            view.isUserInteractionEnabled = false
            view.backgroundColor = .black.withAlphaComponent(0.5)
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.alpha = 0

            window.addSubview(view)
            hoverView = view
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                view.alpha = 1
            }
        }

        window?.isUserInteractionEnabled = false
    }

    private static func hideHoverView(in view: UIView) {
        let window = view.window

        if let hoverView {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                hoverView.alpha = 0
            } completion: { _ in
                hoverView.removeFromSuperview()
            }
        }

        window?.isUserInteractionEnabled = true
        hoverView = nil
    }

    static func setupHUD() {
        ProgressHUD.marginSize = 64
        ProgressHUD.colorBackground = .clear
        ProgressHUD.colorHUD = .systemBackground
        ProgressHUD.colorAnimation = .label
        ProgressHUD.fontStatus = UIFont.preferredFont(forTextStyle: .title3)
    }

    static func showHUD(in view: UIView, setupClosure: (() -> Void)? = nil) {
        setupHUD()
        showHoverView(in: view)
        setupClosure?()
    }

    static func dismissHUD(in view: UIView, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            ProgressHUD.dismiss()
            completion?()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
            hideHoverView(in: view)
        }
    }

    static func accessibilityAnnounce(_ text: String) {
        UIAccessibility.post(
            notification: .announcement,
            argument: NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        )
    }
}
