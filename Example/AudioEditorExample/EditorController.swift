//
//  EditorController.swift
//  AudioEditorExample
//
//  Created by 秋星桥 on 5/1/25.
//

import AudioEditorKit
import SwiftUI
import UIKit

struct EditorController: UIViewControllerRepresentable {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(fileName: String) {
        url = Bundle.main.url(forResource: fileName, withExtension: nil)!
    }

    func makeUIViewController(context _: Context) -> PrePresentationViewController {
        PrePresentationViewController(url: url)
    }

    func updateUIViewController(_: PrePresentationViewController, context _: Context) {}
}
