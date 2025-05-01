//
//  AudioClipNavigationController.swift
//  TRApp
//
//  Created by Rachel on 12/20/24.
//

import UIKit

public final class AudioClipNavigationController: UINavigationController {
    override public func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableDefaultPanGestures()
    }

    override public func willTransition(to newCollection: UITraitCollection, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
        }) { [weak self] _ in
            self?.disableDefaultPanGestures()
        }
    }

    public func disableDefaultPanGestures() {
        for recognizer in presentationController?.presentedView?.gestureRecognizers ?? [] {
            if recognizer is UIPanGestureRecognizer {
                recognizer.isEnabled = false
            }
        }
    }
}
