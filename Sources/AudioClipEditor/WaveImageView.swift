//
//  WaveImageView.swift
//  AudioEditorKit
//
//  Created by 秋星桥 on 5/1/25.
//

import Combine
import UIKit
import WaveformAnalyzer

class WaveImageView: UIView {
    var isTransitionEnabled: Bool = true
    var contentInsets: UIEdgeInsets { .init(top: 8, left: 0, bottom: 8, right: 0) }
    var foregroundColor: UIColor { .secondaryLabel }

    // MARK: - Updates

    private var cancellables = Set<AnyCancellable>()
    private var ongoingTasks = Set<AnyCancellable>()

    private let pendingUpdate = PassthroughSubject<Bool, Never>()

    private var pendingAudioURL: URL?
    private var previousSize: CGSize = .zero
    private var previousEqutableAttributes: EqutableAttributes?
    private var previousScreenScale: CGFloat?

    // MARK: - Views

    private lazy var waveImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.tintColor = foregroundColor
        return view
    }()

    private lazy var shineView: UIView = {
        let view = UIView()
        view.alpha = 0
        view.backgroundColor = .systemBackground.withAlphaComponent(0.2)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private var shineAnimation: CABasicAnimation?

    private lazy var overLengthLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Preview Disabled", bundle: .module)
        label.textColor = foregroundColor
        label.font = .rounded(ofTextStyle: .footnote, weight: .regular)
        label.numberOfLines = 1
        label.minimumScaleFactor = 0.5
        label.alpha = 0.5
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        label.isAccessibilityElement = false
        return label
    }()

    private func finalizeWaveImage(_ image: UIImage, url: URL) {
        guard pendingAudioURL == url else {
            return
        }

        viewState = .done(url)
        if isTransitionEnabled {
            UIView.transition(
                with: waveImageView,
                duration: 0.15,
                options: .transitionCrossDissolve,
                animations: { [weak self] in
                    self?.waveImageView.image = image
                },
                completion: nil
            )
        } else {
            waveImageView.image = image
        }
    }

    // MARK: - View States

    enum ViewState {
        case none /* nothing */
        case loading(URL) /* shineView */
        case done(URL) /* waveImageView */
        case overflow /* overLengthLabel */
    }

    private(set) var viewState: ViewState = .none {
        didSet { reloadViewState() }
    }

    private func reloadViewState() {
        switch viewState {
        case .none:
            shineView.isHidden = true
            if shineAnimation != nil {
                shineView.layer.removeAnimation(forKey: "shine")
                shineAnimation = nil
            }
            overLengthLabel.isHidden = true
            waveImageView.isHidden = true
            waveImageView.image = nil
        case .loading:
            shineView.isHidden = false
            if shineAnimation == nil {
                let shineAnimation = CABasicAnimation(keyPath: "opacity")
                shineAnimation.fromValue = 0.0
                shineAnimation.toValue = 1.0
                shineAnimation.duration = 0.5
                shineAnimation.repeatCount = .infinity
                shineAnimation.autoreverses = true
                shineView.layer.add(shineAnimation, forKey: "shine")
                self.shineAnimation = shineAnimation
            }
            overLengthLabel.isHidden = true
            waveImageView.isHidden = true
            waveImageView.image = nil
        case .overflow:
            shineView.isHidden = true
            if shineAnimation != nil {
                shineView.layer.removeAnimation(forKey: "shine")
                shineAnimation = nil
            }
            overLengthLabel.isHidden = false
            waveImageView.isHidden = true
            waveImageView.image = nil
        case .done:
            shineView.isHidden = true
            if shineAnimation != nil {
                shineView.layer.removeAnimation(forKey: "shine")
                shineAnimation = nil
            }
            overLengthLabel.isHidden = true
            waveImageView.isHidden = false
        }
    }

    // MARK: - Initialization

    init() {
        super.init(frame: .zero)
        _commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _commonInit()
    }

    private func _commonInit() {
        clipsToBounds = true

        addSubview(waveImageView)
        addSubview(shineView)
        addSubview(overLengthLabel)

        NSLayoutConstraint.activate([
            waveImageView.leadingAnchor
                .constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            waveImageView.trailingAnchor
                .constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            waveImageView.topAnchor
                .constraint(equalTo: topAnchor, constant: contentInsets.top),
            waveImageView.bottomAnchor
                .constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom),
        ])

        NSLayoutConstraint.activate([
            shineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            shineView.topAnchor.constraint(equalTo: topAnchor),
            shineView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            overLengthLabel.leadingAnchor
                .constraint(equalTo: leadingAnchor, constant: 8),
            overLengthLabel.trailingAnchor
                .constraint(equalTo: trailingAnchor, constant: -8),
            overLengthLabel.topAnchor
                .constraint(equalTo: topAnchor, constant: 8),
            overLengthLabel.bottomAnchor
                .constraint(equalTo: bottomAnchor, constant: -8),
        ])

        pendingUpdate
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.performUpdate(force: $0)
            }
            .store(in: &cancellables)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pendingUpdate.send(false)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        pendingUpdate.send(false)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelOngoingTasks()
        } else if case .none = viewState {
            pendingUpdate.send(false)
        }
        previousScreenScale = window?.windowScene?.screen.scale
    }

    deinit {
        cancelOngoingTasks()
    }

    // MARK: - Public Methods

    func setupWaveImage(_ url: URL, force: Bool = false) {
        pendingAudioURL = url
        pendingUpdate.send(force)
    }

    func clearWaveImage(isOverflow: Bool) {
        cancelOngoingTasks()
        pendingAudioURL = nil
        viewState = isOverflow ? .overflow : .none
    }

    // MARK: - Private Methods

    private func cancelOngoingTasks() {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
    }

    private func performUpdate(force: Bool) {
        /* no url */
        guard let pendingAudioURL else {
            return
        }

        /* ignore invalid size */
        guard bounds.width > 100, bounds.height > 20 else {
            return
        }

        var sizeOrAttributesChanged = false

        /* size changed? */
        if !previousSize.isNearlyEqual(to: bounds.size) {
            previousSize = bounds.size
            sizeOrAttributesChanged = true
        }

        /* attributes changed? */
        if previousEqutableAttributes != traitCollection.equtableAttributes {
            previousEqutableAttributes = traitCollection.equtableAttributes
            sizeOrAttributesChanged = true
        }

        /* url changed? */
        if !sizeOrAttributesChanged {
            switch viewState {
            case .none, .overflow:
                break
            case let .loading(url): fallthrough
            case let .done(url):
                if force {
                    break
                } else if url == pendingAudioURL {
                    return
                }
            }
        }

        cancelOngoingTasks()
        viewState = .loading(pendingAudioURL)

        Task(priority: .userInitiated) {
            let drawer = WaveformImageDrawer()
            let image = try await withTaskCancellationHandler {
                try await drawer.waveformImage(
                    fromAudioAt: pendingAudioURL,
                    with: Self.waveConfiguration(scale: 2).with(size: bounds.inset(by: contentInsets).size)
                )
            } onCancel: {
                drawer.cancel()
            }

            /* check cancellation */
            try Task.checkCancellation()

            /* finalize */
            await MainActor.run {
                finalizeWaveImage(
                    image.withRenderingMode(.alwaysTemplate),
                    url: pendingAudioURL
                )
            }

        }.store(in: &ongoingTasks)
    }

    private static func waveConfiguration(scale: CGFloat) -> Waveform.Configuration {
        Waveform.Configuration(
            size: .zero,
            backgroundColor: .clear,
            style: .striped(.init(
                color: .white,
                width: 1,
                spacing: 1,
                lineCap: .butt
            )),
            damping: nil,
            scale: scale,
            verticalScalingFactor: 1.0,
            shouldAntialias: false
        )
    }

    private func writeImageToDiskCache(_ image: UIImage, url: URL) {
        image.writeToDiskCache(url)
    }
}

// MARK: - Private Extensions

private extension UIImage {
    static func imageFromDiskCache(_: URL) -> UIImage? {
//        Dynamic(className: "UIImage")
//            .image(WithContentsOfCPBitmapFile: url.path as NSString, flags: 0).asObject as? UIImage
        nil
    }

    func writeToDiskCache(_: URL) {
//        Dynamic(self)
//            .writeToCPBitmapFile(url.path as NSString, flags: 0)
    }
}

private extension CGSize {
    func isNearlyEqual(to size: CGSize, epsilon: CGFloat = 2.0) -> Bool {
        abs(width - size.width) < epsilon && abs(height - size.height) < epsilon
    }
}

private extension UITraitCollection {
    var equtableAttributes: EqutableAttributes {
        .init(self)
    }
}

private struct EqutableAttributes: Equatable {
    let verticalSizeClass: UIUserInterfaceSizeClass
    let horizontalSizeClass: UIUserInterfaceSizeClass

    init(_ traitCollection: UITraitCollection) {
        verticalSizeClass = traitCollection.verticalSizeClass
        horizontalSizeClass = traitCollection.horizontalSizeClass
    }
}

private extension Task {
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(AnyCancellable(cancel))
    }
}
