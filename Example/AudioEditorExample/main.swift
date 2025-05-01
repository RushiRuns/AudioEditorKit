//
//  main.swift
//  AudioEditorExample
//
//  Created by 秋星桥 on 5/1/25.
//

import Foundation
import AVKit

try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
try? AVAudioSession.sharedInstance().setActive(true)

ExampleApp.main()
