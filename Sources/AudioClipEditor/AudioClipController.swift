//
//  AudioClipController.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/16.
//

import AudioClip
import AudioClipPlayer
import AudioClipView
import Combine
import ProgressHUD
import UIKit

public final class AudioClipController: UIViewController {
    public var audio: AudioFileRepresentable!
    // did changed, new file
    public typealias AudioEditorCompletionHandler = (Bool, URL?) -> Void
    public var completionHandler: AudioEditorCompletionHandler?

    private(set) var context: AudioClipContext!
    private var contextCancellables = Set<AnyCancellable>()
    private var isContextLoaded: Bool = false {
        didSet {
            reloadEditableState()
        }
    }

    private var audioClip: AudioClip { context.current.value }
    private var audioClipCancellables = Set<AnyCancellable>()
    private var isPlayingStartedManually: Bool = false

    let sharedPlayer = AudioClipPlayer.shared
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    // MARK: - Outlets

    @IBOutlet var cancelButtonItem: UIBarButtonItem!
    @IBOutlet var saveButtonItem: UIBarButtonItem!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var durationLabel: UILabel!

    @IBOutlet var currentTimeLabel: UILabel!
    @IBOutlet var trimButton: UIButton!
    @IBOutlet var playPauseButtonEffectView: RoundedBackgroundEffectView!
    @IBOutlet var playPauseButton: UIButton!
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var goBackwardButton: UIButton!
    @IBOutlet var goForwardButton: UIButton!

    @IBOutlet var beginTimeLabel: UILabel!
    @IBOutlet var endTimeLabel: UILabel!
    @IBOutlet var messageLabel: UILabel!

    @IBOutlet var clipOverlayView: AudioClipOverlayView!

    @IBOutlet var miniPreviewImageView: WaveImageView!
    @IBOutlet var miniPreviewOverlayView: AudioClipPreviewOverlayView!

    private lazy var playPauseButtonConfiguration: UIButton.Configuration = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "play.fill")
        configuration.baseForegroundColor = .label
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(font: isPad ? .systemFont(ofSize: 38.0, weight: .regular) : .preferredFont(forTextStyle: .largeTitle))
        return configuration
    }()

    // MARK: - Actions

    private func breakDeceleration() {
        clipOverlayView.breakDeceleration()
    }

    func tearDownPlayer(beforeSave: Bool) {
        sharedPlayer.endEditing()
        if isPlayingStartedManually, sharedPlayer.isPlaying {
            if beforeSave {
                sharedPlayer.stop()
            } else {
                sharedPlayer.pause()
            }
        }
    }

    func tearDownTimers() {
        displayLink.invalidate()
        progressTimer.invalidate()
    }

    private func _cancelAction() {
        tearDownPlayer(beforeSave: false)
        tearDownTimers()
        dismiss(animated: true) { [weak self] in
            self?.completionHandler?(false, nil)
        }
    }

    @IBAction func cancelAction(_: UIBarButtonItem) {
        guard !hasFatalError else {
            _cancelAction()
            return
        }
        if context.isAbleToSave {
            let alertCtrl = UIAlertController(
                title: String(localized: "Discard Changes", bundle: .module),
                message: String(localized: "Are you sure you want to discard the changes you made?", bundle: .module),
                preferredStyle: .alert
            )

            alertCtrl.addAction(title: String(localized: "Cancel", bundle: .module), style: .cancel)
            alertCtrl.addAction(title: String(localized: "Discard", bundle: .module), style: .destructive) { [weak self] _ in
                self?._cancelAction()
            }

            present(alertCtrl, animated: true)
        } else {
            _cancelAction()
        }
    }

    @IBAction func saveAction(_: UIBarButtonItem) {
        _saveAction()
    }

    @IBAction func trimAction(_: UIButton) {
        breakDeceleration()
        do {
            try context.trim()
        } catch {
            presentFatalError(message: error.localizedDescription)
        }
    }

    @IBAction func deleteAction(_: UIButton) {
        breakDeceleration()
        do {
            try context.delete()
        } catch {
            presentFatalError(message: error.localizedDescription)
        }
    }

    @IBAction func playPauseAction(_: UIButton) {
        breakDeceleration()
        playerSeekToClipStartIfNeeded()
        sharedPlayer.isPlaying.toggle()
        reloadPlayPauseButton()
        isPlayingStartedManually = true
    }

    @IBAction func goBackwardAction(_: UIButton) {
        breakDeceleration()
        sharedPlayer.beginEditing()
        defer { sharedPlayer.endEditing() }
        sharedPlayer.currentTime = clamp(sharedPlayer.currentTime - 15, to: audioClip.timeRange)
    }

    @IBAction func goForwardAction(_: UIButton) {
        breakDeceleration()
        sharedPlayer.beginEditing()
        defer { sharedPlayer.endEditing() }
        sharedPlayer.currentTime = clamp(sharedPlayer.currentTime + 15, to: audioClip.timeRange)
    }

    // MARK: - Life Cycle

    private lazy var _undoManager = UndoManager()
    override public var undoManager: UndoManager? {
        _undoManager
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupOutlets()
        setupContext()

        guard !hasFatalError else {
            return
        }

        registerContextCancellables()

        RunLoop.main.add(progressTimer, forMode: .common)
        displayLink.add(to: .main, forMode: .common)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController as? AudioClipNavigationController {
            navigationController.disableDefaultPanGestures()
        }
        becomeFirstResponder()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }

    override public var canBecomeFirstResponder: Bool {
        true
    }

    private func registerContextCancellables() {
        contextCancellables.forEach { $0.cancel() }
        contextCancellables.removeAll()

        context.current
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadPlayerIfNeeded()
                self?.reloadViewStates()
                self?.registerAudioClipCancellables()
            }
            .store(in: &contextCancellables)
    }

    private func registerAudioClipCancellables() {
        audioClipCancellables.forEach { $0.cancel() }
        audioClipCancellables.removeAll()

        audioClip.$isEditable
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadEditableState()
            }
            .store(in: &audioClipCancellables)
    }

    deinit {
        tearDownTimers()
    }

    private func setupOutlets() {
        title = String(localized: "Trim", bundle: .module)

        trimButton.setAttributedTitle(NSAttributedString(
            string: String(localized: "Trim", bundle: .module),
            attributes: [.font: UIFont.systemFont(ofSize: 15.0, weight: .semibold)]
        ), for: .normal)

        deleteButton.setAttributedTitle(NSAttributedString(
            string: String(localized: "Delete", bundle: .module),
            attributes: [.font: UIFont.systemFont(ofSize: 15.0, weight: .semibold)]
        ), for: .normal)

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: isPad ? 38.0 : 46.0, weight: .semibold)

        playPauseButton.configuration = playPauseButtonConfiguration
        playPauseButton.automaticallyUpdatesConfiguration = true
        playPauseButton.configurationUpdateHandler = { [weak self] _ in
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveLinear) { [weak self] in
                self?.updatePlayPauseButton()
            }
        }

        titleLabel.text = audio.aliasTitle
        subtitleLabel.text = audio.descriptionText

        let zeroDurationText = TimeInterval(0).preciseDurationString()
        beginTimeLabel.text = zeroDurationText
        if audio.duration > 0 {
            let durationText = audio.duration.preciseDurationString()
            durationLabel.text = durationText
            endTimeLabel.text = durationText
        } else {
            durationLabel.text = zeroDurationText
            endTimeLabel.text = zeroDurationText
        }

        goBackwardButton.accessibilityLabel = String(localized: "Rewind 15 Seconds", bundle: .module)
        goForwardButton.accessibilityLabel = String(localized: "Forward 15 Seconds", bundle: .module)
    }

    private func setupContext() {
        do {
            context = try AudioClipContext(
                contentsOf: audio.url,
                undoManager: _undoManager
            )
            // 如果 aac 压缩音频较长，会导致波形生成时间过长，所以需要异步解码为 pcm 后再生成波形
            if context.shouldRenderWaveform {
                isContextLoaded = true
            } else {
                standardizeContext { [weak self] in
                    self?.isContextLoaded = true
                }
            }
        } catch {
            presentFatalError(message: error.localizedDescription)
        }
    }

    // MARK: - Player

    private func reloadPlayerIfNeeded() {
        guard !hasFatalError else {
            return
        }

        if sharedPlayer.isPrepared(for: context.currentURL) {
            return
        }

        do {
            try sharedPlayer.prepare(context.currentURL, userInfo: audio.extraNowPlayingInfo)
            playerSeekToClipStart()
        } catch {
            presentFatalError(message: error.localizedDescription)
        }
    }

    private func playerSeekToClipStartIfNeeded() {
        if sharedPlayer.currentTime >= audioClip.endTime {
            playerSeekToClipStart()
        }
    }

    private func playerSeekToClipStart() {
        sharedPlayer.beginEditing()
        sharedPlayer.currentTime = audioClip.startTime
        sharedPlayer.endEditing()
    }

    // MARK: - View States

    private var hasFatalError: Bool = false {
        didSet {
            reloadViewStates()
        }
    }

    func presentFatalError(message: String) {
        messageLabel.text = message
        hasFatalError = true
    }

    private func reloadViewStates() {
        if hasFatalError {
            blockUserInteractions()
            return
        }

        reloadEditableState()
        reloadPersistentTimeLabels()
        reloadCurrentTimeLabel()
        reloadPlayPauseButton()
        reloadClipOverlayView()
        reloadMiniPreviewImageView()
        reloadMiniPreviewOverlayView()
    }

    private func blockUserInteractions() {
        messageLabel.isHidden = false
        cancelButtonItem.isEnabled = true
        saveButtonItem.isEnabled = false
        trimButton.isEnabled = false
        goBackwardButton.isEnabled = false
        playPauseButton.isEnabled = false
        goForwardButton.isEnabled = false
        deleteButton.isEnabled = false
        clipOverlayView.isForbidden = true
        miniPreviewOverlayView.isEnabled = false
    }

    private func reloadEditableState() {
        let isAbleToSave = context.isAbleToSave
        let isEditable = audioClip.isEditable

        messageLabel.isHidden = true
        cancelButtonItem.isEnabled = true
        saveButtonItem.isEnabled = isAbleToSave
        trimButton.isEnabled = isEditable
        goBackwardButton.isEnabled = true
        playPauseButton.isEnabled = true
        goForwardButton.isEnabled = true
        deleteButton.isEnabled = isEditable
        clipOverlayView.isForbidden = !isContextLoaded
        miniPreviewOverlayView.isEnabled = true
    }

    private func reloadPersistentTimeLabels() {
        precondition(!hasFatalError)
        beginTimeLabel.text = TimeInterval(0).preciseDurationString()

        let durationText = audioClip.duration.preciseDurationString()
        durationLabel.text = durationText
        endTimeLabel.text = durationText
    }

    // MARK: - Progress Timer

    private lazy var progressTimer = Timer(timeInterval: 1e-2, repeats: true) { [weak self] _ in
        self?.progressTimerTick()
    }

    private func progressTimerTick() {
        reloadCurrentTimeLabel()
        reloadPlayPauseButton()
    }

    private func reloadCurrentTimeLabel() {
        guard !hasFatalError else {
            return
        }

        currentTimeLabel.text = sharedPlayer.currentMediaTime
            .preciseDurationString(includingMilliseconds: true)
    }

    private var previousIsPlaying: Bool = false

    private func reloadPlayPauseButton() {
        guard !hasFatalError else {
            return
        }

        let isPlaying = sharedPlayer.isPlaying
        if previousIsPlaying != isPlaying {
            playPauseButton.accessibilityLabel = (isPlaying
                ? String(localized: "Pause", bundle: .module)
                : String(localized: "Play", bundle: .module))

            playPauseButton.configuration?.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
            playPauseButton.setNeedsUpdateConfiguration()

            updatePlayPauseButton()
            previousIsPlaying = isPlaying
        }
    }

    private func updatePlayPauseButton() {
        playPauseButton.transform = playPauseButton.isHighlighted ? .identity.scaledBy(x: 0.8, y: 0.8) : .identity
        playPauseButtonEffectView.isHighlighted = playPauseButton.isHighlighted
    }

    private func reloadClipOverlayView() {
        clipOverlayView.audioClip = audioClip
        clipOverlayView.player = sharedPlayer
    }

    private func reloadMiniPreviewImageView() {
        if context.shouldRenderWaveform {
            miniPreviewImageView.setupWaveImage(context.currentPreviewURL)
        } else {
            miniPreviewImageView.clearWaveImage(isOverflow: true)
        }
    }

    private func reloadMiniPreviewOverlayView() {
        miniPreviewOverlayView.audioClip = audioClip
        miniPreviewOverlayView.player = sharedPlayer
    }

    // MARK: - Display Link

    private lazy var displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))

    @objc private func displayLinkTick(_: CADisplayLink) {
        let currentTime = sharedPlayer.currentMediaTime
        if currentTime >= audioClip.endTime {
            sharedPlayer.pause()
        }
        audioClip.currentTime = currentTime
        audioClip.isPlaying = sharedPlayer.isPlaying
    }
}
