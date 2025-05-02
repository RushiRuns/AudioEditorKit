//
//  main.swift
//  AudioEditorExample
//
//  Created by 秋星桥 on 5/1/25.
//

import AVKit
import Foundation

try? AVAudioSession.sharedInstance().setCategory(
    .playback,
    options: [.mixWithOthers]
)
try? AVAudioSession.sharedInstance().setActive(true)

ExampleApp.main()
