//
//  AudioFileRepresentable.swift
//  AudioEditorKit
//
//  Created by 秋星桥 on 5/1/25.
//

import AVFAudio
import Foundation

public struct AudioFileRepresentable {
    public var url: URL
    public var aliasTitle: String = .init(localized: "Audio File")
    public var descriptionText: String = ""
    public var duration: TimeInterval

    public var exportAudioSettings: [String: Any] = [:]
    public var extraNowPlayingInfo: [String: Any] = [:]

    public init(
        url: URL,
        aliasTitle: String,
        descriptionText: String,
        duration: TimeInterval? = nil,
        exportAudioSettings: [String: Any] = [:],
        extraNowPlayingInfo: [String: Any] = [:]
    ) {
        self.url = url
        self.aliasTitle = aliasTitle
        self.descriptionText = descriptionText
        if let duration {
            self.duration = duration
        } else if let file = try? AVAudioFile(forReading: url) {
            self.duration = file.duration
        } else {
            self.duration = 0
        }
        self.exportAudioSettings = exportAudioSettings
        self.extraNowPlayingInfo = extraNowPlayingInfo
    }
}
