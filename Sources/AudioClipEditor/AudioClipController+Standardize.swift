//
//  AudioClipController+Standardize.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/29.
//

import ProgressHUD
import UIKit

public extension AudioClipController {
    func standardizeContext(completion: (() -> Void)? = nil) {
        _standardizeContextPrepare()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?._standardizeContextFinalize(completion: completion)
        }
    }

    private func _standardizeContextPrepare() {
        sharedPlayer.stop()

        ProgressHUDManager.showHUD(in: view) {
            ProgressHUD.animate(
                String(localized: "Decoding", bundle: .module),
                .circleDotSpinFade,
                interaction: false
            )
            ProgressHUDManager.accessibilityAnnounce(String(localized: "Decoding", bundle: .module))
        }
    }

    private func _standardizeContextFinalize(completion: (() -> Void)? = nil) {
        do {
            try context.standardize()

            DispatchQueue.main.async { [weak self] in
                self?._standardizeContextCompleted(completion: completion)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?._standardizeContextErrorOccurred(error)
            }
        }
    }

    private func _standardizeContextCompleted(completion: (() -> Void)? = nil) {
        ProgressHUDManager.dismissHUD(in: view, completion: completion)
    }

    private func _standardizeContextErrorOccurred(_ error: Error) {
        ProgressHUD.failed(String(localized: "Operation Failed", bundle: .module), delay: 2.0)
        ProgressHUDManager.accessibilityAnnounce(String(localized: "Operation Failed", bundle: .module))

        view.isUserInteractionEnabled = false
        ProgressHUDManager.dismissHUD(in: view, delay: 2.0) { [weak self] in
            guard let self else { return }
            presentFatalError(message: error.localizedDescription)
            view.isUserInteractionEnabled = true
        }
    }
}
