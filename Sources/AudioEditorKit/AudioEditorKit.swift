// The Swift Programming Language
// https://docs.swift.org/swift-book

@_exported import AudioClip
@_exported import AudioClipEditor
@_exported import AudioClipView
@_exported import WaveformAnalyzer

import UIKit

public enum AudioEditorKit {
    public static func presentEditor(
        audio: AudioFileRepresentable,
        parent: UIViewController,
        completion: @escaping AudioClipController.AudioEditorCompletionHandler
    ) {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let storyboard = UIStoryboard(
            name: isPad ? "AudioClipController_iPad" : "AudioClipController",
            bundle: AudioClipControllerBundle.bundle
        )
        let navController = storyboard.instantiateInitialViewController()
            as! UINavigationController
        navController.modalPresentationStyle = .formSheet
        navController.modalTransitionStyle = .coverVertical
        navController.preferredContentSize = CGSize(width: 666, height: 666)

        let controller = navController.viewControllers.first
            as! AudioClipController
        controller.audio = audio
        controller.completionHandler = completion

        parent.present(navController, animated: true)
    }
}
