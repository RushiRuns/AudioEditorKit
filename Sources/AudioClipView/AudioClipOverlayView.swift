//
//  AudioClipOverlayView.swift
//  TRApp
//
//  Created by 82Flex on 2024/12/29.
//

import AudioClip
import AudioClipPlayer
import Combine
import UIKit

public final class AudioClipOverlayView: UIView {
    private(set) lazy var containerView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var scrollView: AudioClipScrollView = {
        let view = AudioClipScrollView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var pinchView: AudioClipPinchView = {
        let view = AudioClipPinchView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var controlView: AudioClipControlView = {
        let view = AudioClipControlView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public weak var audioClip: AudioClip? {
        didSet {
            controlView.audioClip = audioClip
            pinchView.audioClip = audioClip
            scrollView.audioClip = audioClip
            viewStateSubject.send(.ready)
        }
    }

    public weak var player: AudioClipPlayer? {
        didSet {
            controlView.player = player
            reloadPlayer()
        }
    }

    public var isForbidden: Bool = false {
        didSet {
            if case .forbidden = viewStateSubject.value {
                if !isForbidden {
                    viewStateSubject.send(.ready)
                    _registerObservers()
                }
            } else {
                if isForbidden {
                    viewStateSubject.send(.forbidden)
                    _unregisterObservers()
                }
            }
        }
    }

    public var isPlayingInitially: Bool = false

    private func reloadAudioClip() {
        guard viewStateSubject.value.isReadyOrFailed else {
            return
        }

        audioClipCancellables.forEach { $0.cancel() }
        audioClipCancellables.removeAll()

        playerTrackCancellables.forEach { $0.cancel() }
        playerTrackCancellables.removeAll()

        if let audioClip {
            beginDrawValues = AudioClipDrawValues(zoomFactor: audioClip.zoomFactor ?? Self.suggestedZoomScale(for: audioClip.duration))

            audioClip.$isPlaying
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] isPlaying in
                    self?.trackMode = isPlaying ? .followPlayer : .followScrollView(false)
                }
                .store(in: &audioClipCancellables)

            audioClip.inProgressEditorIdentifier
                .removeDuplicates()
                .sink { [weak self] editor in
                    guard let self else { return }
                    if let editor {
                        if editor != hashValue {
                            breakDeceleration()
                        }
                    } else {
                        scrollView.setNeedsUpdateContentSizeAndScrollableArea()
                        if case .followScrollView = trackMode {
                            scrollToCurrentTime()
                        }
                    }
                }
                .store(in: &audioClipCancellables)

        } else {
            beginDrawValues = AudioClipDrawValues(zoomFactor: Self.initialZoomScale)
            trackMode = .followScrollView(false)
        }

        _initializePinchGesture()
    }

    private func reloadPlayer() {
        if let player, player.isPlaying {
            isPlayingInitially = true
        } else {
            isPlayingInitially = false
        }
    }

    // MARK: - Initialization

    override public func awakeFromNib() {
        super.awakeFromNib()
        _commonInit()
    }

    private func _commonInit() {
        _setupCommonAttributes()
        _setupPinchGesture()
        _setupSubviews()
        _registerObservers()
    }

    private func _setupCommonAttributes() {
        backgroundColor = .clear
    }

    private func _setupPinchGesture() {
        addGestureRecognizer(pinchGesture)
    }

    private func _setupSubviews() {
        addSubview(containerView)
        containerView.addSubview(scrollView)
        containerView.addSubview(controlView)
        containerView.addSubview(pinchView)

        controlView.scrollView = scrollView
        scrollView.controlView = controlView

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AudioClipControlView.anchorCircleSpacing),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            controlView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            controlView.topAnchor.constraint(equalTo: containerView.topAnchor),
            controlView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            pinchView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pinchView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pinchView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pinchView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    private func _registerObservers() {
        delayedAvailableSubject
            .delay(for: 0.25, tolerance: 0.05, scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.viewStateSubject.send(.available)
            }
            .store(in: &viewCancellables)

        debouncedLoadingSubject
            .debounce(for: 0.25, scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.reloadAudioClip()
            }
            .store(in: &viewCancellables)

        zoomScaleSubject
            .sink { [weak self] in
                self?.updateZoomScale($0)
            }
            .store(in: &viewCancellables)

        pinchScaleSubject
            .sink { [weak self] in
                self?.updatePinchScale($0)
            }
            .store(in: &viewCancellables)

        viewStateSubject
            .sink { [weak self] in
                self?.viewStateChanged($0)
            }
            .store(in: &viewCancellables)
    }

    private func _unregisterObservers() {
        viewCancellables.forEach { $0.cancel() }
        viewCancellables.removeAll()
    }

    // MARK: - View States

    public enum ViewState: Equatable {
        // 被禁用
        case forbidden

        // 就绪
        case ready

        // 捏合中
        case pinching

        // 捏合完成，加载波形中
        case loading(isInitial: Bool)

        // 波形加载完成，延迟等待视图布局
        case loaded(isInitial: Bool)

        // 视图布局完成
        case available

        // 失败
        case failed

        var isReadyOrFailed: Bool {
            switch self {
            case .ready, .failed:
                true
            default:
                false
            }
        }

        var isLoading: Bool {
            switch self {
            case .loading:
                true
            default:
                false
            }
        }

        var isLoadedOrAvailable: Bool {
            switch self {
            case .loaded, .available:
                true
            default:
                false
            }
        }
    }

    private var viewCancellables = Set<AnyCancellable>()
    private lazy var pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))

    public var beginDrawValues = AudioClipDrawValues()

    let zoomScaleSubject = CurrentValueSubject<CGFloat, Never>(initialZoomScale)
    let pinchScaleSubject = CurrentValueSubject<CGFloat, Never>(initialZoomScale)

    let viewStateSubject = CurrentValueSubject<ViewState, Never>(.ready)
    private let debouncedLoadingSubject = PassthroughSubject<Void, Never>()
    private let delayedAvailableSubject = PassthroughSubject<Void, Never>()

    private func viewStateChanged(_ viewState: ViewState) {
        let isAnimated = switch viewState {
        case .forbidden:
            true
        case .ready:
            true
        case .pinching:
            false
        case .loading:
            false
        case .loaded:
            true
        case .available:
            true
        case .failed:
            true
        }

        if isAnimated {
            UIView.transition(
                with: self,
                duration: 0.15,
                options: .transitionCrossDissolve
            ) { [weak self] in
                self?._viewStateChanged(viewState)
            } completion: { _ in
                print(#fileID, "overlay view state changed to \(viewState)")
            }
        } else {
            _viewStateChanged(viewState)
            print(#fileID, "overlay view state changed to \(viewState)")
        }
    }

    private func _viewStateChanged(_ viewState: ViewState) {
        var shouldAllowContentDrawing = false
        switch viewState {
        case .forbidden, .ready, .failed:
            isUserInteractionEnabled = false
            containerView.isHidden = true
            scrollView.isHidden = true
            scrollView.isContentHidden = true
            controlView.isHidden = true
            pinchView.isHidden = true
            pinchGesture.isEnabled = false
            if case .ready = viewState {
                debouncedLoadingSubject.send()
            }
        case .pinching:
            isUserInteractionEnabled = true
            containerView.isHidden = false
            scrollView.isHidden = false
            scrollView.isContentHidden = true
            controlView.isHidden = true
            pinchView.isHidden = false
            pinchGesture.isEnabled = true
        case let .loading(isInitial):
            isUserInteractionEnabled = false
            containerView.isHidden = false
            scrollView.isHidden = false
            scrollView.isContentHidden = true
            controlView.isHidden = true
            pinchView.isHidden = isInitial
            pinchGesture.isEnabled = false
        case let .loaded(isInitial):
            isUserInteractionEnabled = false
            containerView.isHidden = false
            scrollView.isHidden = false
            scrollView.isContentHidden = isInitial && isPlayingInitially
            controlView.isHidden = isInitial && isPlayingInitially
            pinchView.isHidden = isInitial
            pinchGesture.isEnabled = false
            delayedAvailableSubject.send()
            shouldAllowContentDrawing = true
        case .available:
            isUserInteractionEnabled = shouldAllowUserInteraction
            containerView.isHidden = false
            scrollView.isHidden = false
            scrollView.isContentHidden = false
            controlView.isHidden = false
            pinchView.isHidden = true
            pinchGesture.isEnabled = true
            shouldAllowContentDrawing = true
        }

        if shouldAllowContentDrawing {
            scrollView.unblockContentDrawing()
        } else {
            scrollView.blockContentDrawing()
        }
    }

    // MARK: - Player States

    public var trackMode: TrackMode = .followScrollView(false) {
        didSet {
            reloadTrackMode()
        }
    }

    public var audioClipCancellables = Set<AnyCancellable>()
    public var playerTrackCancellables = Set<AnyCancellable>()
}
