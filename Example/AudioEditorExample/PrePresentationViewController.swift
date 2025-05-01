//
//  PrePresentationViewController.swift
//  AudioEditorExample
//
//  Created by 秋星桥 on 5/1/25.
//

import AudioEditorKit
import SwiftUI
import UIKit

class PrePresentationViewController: UIViewController {
    let url: URL
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    let activityIndicator = UIActivityIndicatorView()

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.style = .large
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        view.backgroundColor = .systemBackground
    }

    var isFirstAppear = true
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard isFirstAppear else {
            dismiss(animated: true)
            return
        }
        isFirstAppear = false
        let rep = AudioFileRepresentable(
            url: url,
            aliasTitle: url.lastPathComponent,
            descriptionText: String(localized: "Example Audio File")
        )
        AudioEditorKit.presentEditor(audio: rep, parent: self) { edited, newURL in
            guard edited, let url = newURL else {
                self.dismiss(animated: true)
                return
            }
            print(url)
            let shared = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            shared.popoverPresentationController?.sourceView = self.activityIndicator
            shared.popoverPresentationController?.sourceRect = self.activityIndicator.bounds
            shared.popoverPresentationController?.permittedArrowDirections = .any
            shared.completionWithItemsHandler = { _, _, _, _ in
                self.dismiss(animated: true)
                try? FileManager.default.removeItem(at: url)
            }
            self.present(shared, animated: true)
        }
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
}
