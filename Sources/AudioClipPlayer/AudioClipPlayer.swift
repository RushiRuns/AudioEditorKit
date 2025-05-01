//
//  AudioClipPlayer.swift
//  TRApp
//
//  Created by Lessica on 2024/7/12.
//

import AVFAudio
import AVKit
import Combine
import Foundation
import MediaPlayer

public final class AudioClipPlayer: NSObject {
    // MARK: - Constants

    fileprivate static let meteringSampleInterval: TimeInterval = 0.1
    fileprivate static let nowPlayingInfoUpdatingInterval: TimeInterval = 5.0
    fileprivate static let reportingInterval: TimeInterval = 1.0

    // MARK: - Instance

    public static let shared = AudioClipPlayer()
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        _ = Self.coverImageArtwork
    }

    // MARK: - Configuration

    public var preferredRate: Float = 1.0
    public var shouldSkipSilence: Bool = false
    public var shouldEnhanceRecording: Bool = false
    public var shouldUseMediaControls: Bool = true

    // MARK: - Player

    private(set) var internalAudioPlayer: AVAudioPlayer?

    // MARK: - Editing && Preparation

    private(set) var isEditing: Bool = false {
        didSet {
            if isEditing {
                print(#fileID, "player begin editing")
            } else {
                print(#fileID, "player end editing")
            }
        }
    }

    // MARK: - Statistics

    private var reportingTimer: Timer?
    private var reportedClockTime: TimeInterval?
    private var reportedCurrentTime: TimeInterval?

    private var aboutToContinuePlayingTime: TimeInterval?

    // MARK: - Metering

    private var meteringTimer: Timer?

    // MARK: - Now Playing

    private var nowPlayingTimer: Timer?
    private var extraNowPlayingInfo: [String: Any] = [:]

    // MARK: - Remote Commands

    private var isRemoteCommandCenterEnabled: Bool = false
    private var isRemoteCommandsRegistered: Bool = false

    private var mPlayCommandTarget: Any?
    private var mPauseCommandTarget: Any?
    private var mSkipBackwardCommandTarget: Any?
    private var mSkipForwardCommandTarget: Any?
    private var mChangePlaybackPositionCommandTarget: Any?
}

// MARK: - Player

public extension AudioClipPlayer {
    var currentDeviceTime: TimeInterval { internalAudioPlayer?.deviceCurrentTime ?? 0 }
    var duration: TimeInterval { internalAudioPlayer?.duration ?? 0 }
    var numberOfChannels: Int { internalAudioPlayer?.numberOfChannels ?? 0 }

    var pan: Float {
        get { internalAudioPlayer?.pan ?? 0 }
        set { internalAudioPlayer?.pan = newValue }
    }

    var rate: Float {
        get { internalAudioPlayer?.rate ?? 1 }
        set { internalAudioPlayer?.rate = newValue }
    }

    var isPlaying: Bool {
        get {
            internalAudioPlayer?.isPlaying ?? false
        }
        set {
            if newValue {
                _ = try? play()
            } else {
                pause()
            }
        }
    }

    var currentTime: TimeInterval {
        get {
            if !isPlaying {
                aboutToContinuePlayingTime ?? 0
            } else {
                internalAudioPlayer?.currentTime ?? 0
            }
        }
        set(inValue) {
            let newValue = max(0, min(inValue, duration))
            if !isPlaying {
                aboutToContinuePlayingTime = newValue
            } else {
                internalAudioPlayer?.currentTime = newValue
                reportedClockTime = CACurrentMediaTime()
                reportedCurrentTime = newValue
                aboutToContinuePlayingTime = newValue
            }
        }
    }

    var currentMediaTime: TimeInterval {
        if !isPlaying {
            return aboutToContinuePlayingTime ?? 0
        }

        if let clockTime = reportedClockTime, let currentTime = reportedCurrentTime {
            let newClockTime = CACurrentMediaTime()
            let mixedTime = currentTime + (newClockTime - clockTime) * Double(rate)

            reportedClockTime = newClockTime
            reportedCurrentTime = mixedTime
            aboutToContinuePlayingTime = mixedTime

            return mixedTime

        } else if let currentTime = commitStatistics() {
            return currentTime
        } else {
            return 0
        }
    }

    func prepare(_ url: URL, userInfo: [String: Any]?) throws {
        precondition(Thread.isMainThread)

        let player = try AVAudioPlayer(contentsOf: url)

        player.delegate = self
        player.isMeteringEnabled = shouldSkipSilence
        player.enableRate = true
        player.rate = preferredRate

        internalAudioPlayer = player

        reloadReportingTimer()
        reloadNowPlayingTimer()
        reloadMediaPlayer()

        player.prepareToPlay()

        if let userInfo {
            extraNowPlayingInfo = userInfo
        } else {
            extraNowPlayingInfo.removeAll()
        }

        commitNowPlayingInfo()
        commitStatistics()
    }

    @discardableResult
    func play() throws -> Bool {
        precondition(Thread.isMainThread)

        guard let player = internalAudioPlayer else {
            return false
        }

        if let aboutToPlay = aboutToContinuePlayingTime {
            aboutToContinuePlayingTime = nil
            if aboutToPlay >= duration {
                player.currentTime = 0
            } else {
                player.currentTime = aboutToPlay
            }
        }

        let didPlay = player.play()
        // try AudioSession.shared.activateAudioSession(category: .playback)

        commitNowPlayingInfo()
        commitStatistics()

        return didPlay
    }

    func pause() {
        precondition(Thread.isMainThread)

        internalAudioPlayer?.pause()

        commitNowPlayingInfo()
        commitStatistics()
    }

    func stop() {
        precondition(Thread.isMainThread)

        internalAudioPlayer?.stop()
        internalAudioPlayer = nil

        reloadReportingTimer()
        reloadNowPlayingTimer()
        reloadMediaPlayer()

        commitNowPlayingInfo()
        commitStatistics()
    }
}

// MARK: - Editing && Preparation

public extension AudioClipPlayer {
    var isPrepared: Bool { internalAudioPlayer != nil }
    func isPrepared(for url: URL) -> Bool { internalAudioPlayer?.url == url }

    func beginEditing() {
        precondition(Thread.isMainThread)
        if !isEditing {
            isEditing = true
        }
    }

    func endEditing() {
        precondition(Thread.isMainThread)
        if isEditing {
            isEditing = false
            commitNowPlayingInfo()
            resetNowPlayingTimer()
        }
    }
}

// MARK: - Statistics

private extension AudioClipPlayer {
    @discardableResult
    func commitStatistics() -> TimeInterval? {
        if isPrepared {
            let underlyingCurrentTime = currentTime
            reportedClockTime = CACurrentMediaTime()
            reportedCurrentTime = underlyingCurrentTime
            aboutToContinuePlayingTime = underlyingCurrentTime
            return underlyingCurrentTime
        } else {
            clearStatistics()
            return nil
        }
    }

    func clearStatistics() {
        reportedClockTime = nil
        reportedCurrentTime = nil
        aboutToContinuePlayingTime = nil
    }

    func reloadReportingTimer() {
        if isPrepared, reportingTimer == nil {
            reportingTimer = Timer.scheduledTimer(
                withTimeInterval: Self.reportingInterval,
                repeats: true
            ) { [unowned self] _ in
                commitStatistics()
            }
            print(#fileID, "player reporting timer started")
        } else if !isPrepared, reportingTimer != nil {
            clearReportingTimer()
            print(#fileID, "player reporting timer stopped")
        }
    }

    func clearReportingTimer() {
        reportingTimer?.invalidate()
        reportingTimer = nil
    }
}

// MARK: - Metering

private extension AudioClipPlayer {
    var isMeteringEnabled: Bool {
        get { internalAudioPlayer?.isMeteringEnabled ?? false }
        set { internalAudioPlayer?.isMeteringEnabled = newValue }
    }

    func updateMeters() {
        internalAudioPlayer?.updateMeters()
    }

    func averagePower(forChannel channelNumber: Int) -> Float {
        internalAudioPlayer?.averagePower(forChannel: channelNumber) ?? 0
    }

    func reloadMeteringTimer() {
        if isMeteringEnabled, meteringTimer == nil {
            meteringTimer = Timer.scheduledTimer(
                timeInterval: Self.meteringSampleInterval,
                target: self,
                selector: #selector(findSilences(_:)),
                userInfo: nil,
                repeats: true
            )
            print(#fileID, "player metering timer started")
        } else if !isMeteringEnabled, meteringTimer != nil {
            clearMeteringTimer()
            print(#fileID, "player metering timer stopped")
        }
    }

    func clearMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        if isPrepared {
            rate = preferredRate
        }
    }

    static let decibelThreshold = Float(-50)
    static let skipSilenceRate = Float(3.0)

    @objc func findSilences(_: Timer) {
        guard isPrepared else {
            clearMeteringTimer()
            return
        }

        guard isPlaying else {
            return
        }

        updateMeters()
        var totalAveragePower: Float = 0
        for i in 0 ..< numberOfChannels {
            totalAveragePower += averagePower(forChannel: i)
        }

        let averagePower = totalAveragePower / Float(numberOfChannels)
        if averagePower < Self.decibelThreshold {
            rate = Self.skipSilenceRate
        } else {
            rate = preferredRate
        }
    }
}

// MARK: - Now Playing

private extension AudioClipPlayer {
    func reloadMediaPlayer() {
        commitNowPlayingInfo()

        let shouldRegister = isRemoteCommandCenterEnabled && isPrepared
        if shouldRegister, !isRemoteCommandsRegistered {
            setupRemoteCommands()
        } else if !shouldRegister, isRemoteCommandsRegistered {
            tearDownRemoteCommands()
        }
    }

    func commitNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = {
            guard isRemoteCommandCenterEnabled, isPrepared else {
                return nil
            }
            var userInfo: [String: Any] = [:]
            userInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime)
            userInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: Double(rate))
            userInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
            userInfo[MPMediaItemPropertyArtwork] = Self.coverImageArtwork
            userInfo.merge(extraNowPlayingInfo) { $1 }
            return userInfo
        }()
    }

    func reloadNowPlayingTimer() {
        let shouldSchedule = isRemoteCommandCenterEnabled && isPrepared
        if shouldSchedule, nowPlayingTimer == nil {
            nowPlayingTimer = Timer.scheduledTimer(
                withTimeInterval: Self.nowPlayingInfoUpdatingInterval,
                repeats: true
            ) { [unowned self] _ in
                commitNowPlayingInfo()
            }
            print(#fileID, "player now playing timer started")
        } else if !shouldSchedule, nowPlayingTimer != nil {
            nowPlayingTimer?.invalidate()
            nowPlayingTimer = nil
            print(#fileID, "player now playing timer stopped")
        }
    }

    func resetNowPlayingTimer() {
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
        reloadNowPlayingTimer()
    }
}

// MARK: - Remote Commands

private extension AudioClipPlayer {
    func setupRemoteCommands() {
        guard !isRemoteCommandsRegistered else {
            return
        }

        defer {
            isRemoteCommandsRegistered = true
        }

        let cmdCenter = MPRemoteCommandCenter.shared()
        cmdCenter.nextTrackCommand.isEnabled = false
        cmdCenter.previousTrackCommand.isEnabled = false

        if let mPlayCommandTarget {
            cmdCenter.playCommand.removeTarget(mPlayCommandTarget)
        }
        cmdCenter.playCommand.isEnabled = true
        mPlayCommandTarget = cmdCenter.playCommand.addTarget { [unowned self] _ in
            guard isPrepared else {
                return .noActionableNowPlayingItem
            }

            guard !isPlaying else {
                return .commandFailed
            }

            do {
                try play()
                return .success
            } catch {
                return .commandFailed
            }
        }

        if let mPauseCommandTarget {
            cmdCenter.pauseCommand.removeTarget(mPauseCommandTarget)
        }
        cmdCenter.pauseCommand.isEnabled = true
        mPauseCommandTarget = cmdCenter.pauseCommand.addTarget { [unowned self] _ in
            guard isPrepared else {
                return .noActionableNowPlayingItem
            }

            guard isPlaying else {
                return .commandFailed
            }

            pause()
            return .success
        }

        if let mSkipBackwardCommandTarget {
            cmdCenter.skipBackwardCommand.removeTarget(mSkipBackwardCommandTarget)
        }
        cmdCenter.skipBackwardCommand.isEnabled = true
        cmdCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15.0)]
        mSkipBackwardCommandTarget = cmdCenter.skipBackwardCommand.addTarget { [unowned self] event in
            guard isPrepared else {
                return .noActionableNowPlayingItem
            }

            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            beginEditing()
            defer { endEditing() }

            if currentTime < skipEvent.interval {
                currentTime = 0
                return .success
            }

            currentTime -= skipEvent.interval
            return .success
        }

        if let mSkipForwardCommandTarget {
            cmdCenter.skipForwardCommand.removeTarget(mSkipForwardCommandTarget)
        }
        cmdCenter.skipForwardCommand.isEnabled = true
        cmdCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15.0)]
        mSkipForwardCommandTarget = cmdCenter.skipForwardCommand.addTarget { [unowned self] event in
            guard isPrepared else {
                return .noActionableNowPlayingItem
            }

            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }

            beginEditing()
            defer { endEditing() }

            if currentTime > duration - skipEvent.interval {
                currentTime = duration
                return .success
            }

            currentTime += skipEvent.interval
            return .success
        }

        if let mChangePlaybackPositionCommandTarget {
            cmdCenter.changePlaybackPositionCommand.removeTarget(mChangePlaybackPositionCommandTarget)
        }
        cmdCenter.changePlaybackPositionCommand.isEnabled = true
        mChangePlaybackPositionCommandTarget = cmdCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in

            guard isPrepared else {
                return .noActionableNowPlayingItem
            }

            guard let changePositionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            beginEditing()
            defer { endEditing() }

            currentTime = changePositionEvent.positionTime
            return .success
        }

        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    func tearDownRemoteCommands() {
        guard isRemoteCommandsRegistered else {
            return
        }

        defer {
            isRemoteCommandsRegistered = false
        }

        UIApplication.shared.endReceivingRemoteControlEvents()

        let cmdCenter = MPRemoteCommandCenter.shared()
        if let mPlayCommandTarget {
            cmdCenter.playCommand.removeTarget(mPlayCommandTarget)
        }
        mPlayCommandTarget = nil

        if let mPauseCommandTarget {
            cmdCenter.pauseCommand.removeTarget(mPauseCommandTarget)
        }
        mPauseCommandTarget = nil

        if let mSkipBackwardCommandTarget {
            cmdCenter.skipBackwardCommand.removeTarget(mSkipBackwardCommandTarget)
        }
        mSkipBackwardCommandTarget = nil

        if let mSkipForwardCommandTarget {
            cmdCenter.skipForwardCommand.removeTarget(mSkipForwardCommandTarget)
        }
        mSkipForwardCommandTarget = nil

        if let mChangePlaybackPositionCommandTarget {
            cmdCenter.changePlaybackPositionCommand.removeTarget(mChangePlaybackPositionCommandTarget)
        }
        mChangePlaybackPositionCommandTarget = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioClipPlayer: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool) {
        commitNowPlayingInfo()
        commitStatistics()

        if successfully { aboutToContinuePlayingTime = player.duration }
    }
}
