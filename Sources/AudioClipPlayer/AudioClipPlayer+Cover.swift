//
//  AudioClipPlayer+Cover.swift
//  TRApp
//
//  Created by Rachel on 13/1/2025.
//

import MediaPlayer

extension AudioClipPlayer {
    static let coverImageArtwork: MPMediaItemArtwork = .init(boundsSize: coverImage.size) { _ in coverImage }

    static let coverImagePNGData: Data? = coverImage.pngData()
    static let coverImageJPEGData: Data? = coverImage.jpegData(compressionQuality: 0.9)
}

private extension AudioClipPlayer {
    static let coverImage: UIImage = {
        precondition(Thread.isMainThread)

        let sideWidth: CGFloat = 1024.0
        let view = UIView(frame: .init(x: 0, y: 0, width: sideWidth, height: sideWidth))
        view.backgroundColor = .white

        let frame = CGRect(
            center: view.center,
            size: .init(width: sideWidth * 0.75, height: sideWidth * 0.75)
        )
        let image = UIImageView(frame: frame)
        image.contentMode = .scaleAspectFit
        image.image = .init(systemName: "music.note.list")
        image.tintColor = .black

        view.addSubview(image)

        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { rendererContext in
            view.layer.render(in: rendererContext.cgContext)
        }
    }()
}

private extension CGRect {
    init(center: CGPoint, size: CGSize) {
        let origin = CGPoint(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0)
        self.init(origin: origin, size: size)
    }
}
