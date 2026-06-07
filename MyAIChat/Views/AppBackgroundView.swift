//
//  AppBackgroundView.swift
//  MyAIChat
//
//  Renders the global app background. Placed behind everything in RootView.
//  Supports: static image, animated GIF, video (loop / ping-pong / once),
//  dim overlay, blur overlay, and UI transparency.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - AppBackgroundView

struct AppBackgroundView: View {
    @ObservedObject private var manager = AppBackgroundManager.shared

    var body: some View {
        let s = manager.settings
        ZStack {
            // 1. Media layer
            mediaLayer(s)
                .ignoresSafeArea()

            // 2. Dim overlay
            if s.dimAmount > 0 {
                Color.black
                    .opacity(s.dimAmount)
                    .ignoresSafeArea()
            }

            // 3. Blur overlay
            if s.blurRadius > 0 {
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(min(s.blurRadius / 30.0, 1.0))
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func mediaLayer(_ s: AppBackgroundSettings) -> some View {
        switch s.type {
        case .none:
            Color.clear

        case .image:
            if let img = manager.backgroundImage {
                StaticImageBackground(image: img, contentMode: s.contentMode)
            } else {
                Color.clear
            }

        case .gif:
            if let url = manager.backgroundFileURL {
                GIFBackground(url: url, loopMode: s.loopMode, contentMode: s.contentMode)
            } else {
                Color.clear
            }

        case .video, .livePhoto:
            if let url = manager.backgroundFileURL {
                VideoBackground(url: url, loopMode: s.loopMode, contentMode: s.contentMode)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - StaticImageBackground

private struct StaticImageBackground: View {
    let image: UIImage
    let contentMode: String

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode == "fit" ? .fit : .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

// MARK: - GIFBackground (uses UIImageView + animated UIImage)

struct GIFBackground: UIViewRepresentable {
    let url: URL
    let loopMode: BackgroundLoopMode
    let contentMode: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
        var loadedLoopMode: BackgroundLoopMode?
        var loadedContentMode: String?
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let imageView = UIImageView()
        imageView.contentMode = contentMode == "fit" ? .scaleAspectFit : .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        loadGIF(into: imageView, context: context)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = uiView.subviews.first as? UIImageView else { return }
        // Only update contentMode without reload if nothing else changed
        imageView.contentMode = contentMode == "fit" ? .scaleAspectFit : .scaleAspectFill
        // Reload GIF only when relevant inputs actually changed
        let c = context.coordinator
        guard c.loadedURL != url || c.loadedLoopMode != loopMode else { return }
        loadGIF(into: imageView, context: context)
    }

    private func loadGIF(into imageView: UIImageView, context: Context) {
        let c = context.coordinator
        c.loadedURL = url
        c.loadedLoopMode = loopMode
        c.loadedContentMode = contentMode
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

            let count = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var totalDuration: Double = 0

            for i in 0 ..< count {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
                let gifProps = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
                let delay = (gifProps?[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
                images.append(UIImage(cgImage: cgImage))
                totalDuration += delay
            }

            if images.isEmpty { return }

            // ping-pong: append reversed frames (without first/last duplicate)
            var finalImages = images
            if loopMode == .pingPong && images.count > 1 {
                let reversed = images.dropFirst().dropLast().reversed()
                finalImages += reversed
            }

            let animated = UIImage.animatedImage(with: finalImages, duration: totalDuration)
            DispatchQueue.main.async {
                imageView.image = animated
                imageView.startAnimating()
                if loopMode == .once {
                    // Stop after one full cycle
                    let duration = totalDuration
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        imageView.stopAnimating()
                        imageView.image = finalImages.last
                    }
                }
            }
        }
    }
}

// MARK: - VideoBackground (AVPlayer based)

struct VideoBackground: UIViewRepresentable {
    let url: URL
    let loopMode: BackgroundLoopMode
    let contentMode: String

    func makeUIView(context: Context) -> VideoBackgroundUIView {
        let view = VideoBackgroundUIView()
        view.configure(url: url, loopMode: loopMode, contentMode: contentMode)
        return view
    }

    func updateUIView(_ uiView: VideoBackgroundUIView, context: Context) {
        uiView.configure(url: url, loopMode: loopMode, contentMode: contentMode)
    }

    static func dismantleUIView(_ uiView: VideoBackgroundUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class VideoBackgroundUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var looper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var observerToken: Any?
    private var currentURL: URL?
    private var currentLoop: BackgroundLoopMode = .loop

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var avPlayerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func configure(url: URL, loopMode: BackgroundLoopMode, contentMode: String) {
        guard url != currentURL || loopMode != currentLoop else { return }
        currentURL  = url
        currentLoop = loopMode

        // Cleanup
        stop()

        avPlayerLayer.videoGravity = contentMode == "fit"
            ? .resizeAspect
            : .resizeAspectFill

        if loopMode == .loop {
            let item       = AVPlayerItem(url: url)
            let qp         = AVQueuePlayer()
            let lp         = AVPlayerLooper(player: qp, templateItem: item)
            queuePlayer    = qp
            looper         = lp
            avPlayerLayer.player = qp
            qp.isMuted     = true
            qp.play()
        } else if loopMode == .pingPong {
            // Ping-pong: forward → reverse → forward …
            let p          = AVPlayer(url: url)
            player         = p
            avPlayerLayer.player = p
            p.isMuted      = true
            p.play()
            setupPingPong(player: p, url: url)
        } else {
            // Once
            let p          = AVPlayer(url: url)
            player         = p
            avPlayerLayer.player = p
            p.isMuted      = true
            p.play()
        }
    }

    private func setupPingPong(player: AVPlayer, url: URL) {
        // Observe end of video, then play backwards
        observerToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self, weak player] _ in
            guard let player else { return }
            self?.reversePlay(player: player, url: url)
        }
    }

    private var isReversed = false
    private func reversePlay(player: AVPlayer, url: URL) {
        isReversed.toggle()
        if isReversed {
            // Seek to end and play at -1
            player.seek(to: player.currentItem?.duration ?? .zero)
            player.rate = -1.0
        } else {
            player.seek(to: .zero)
            player.rate = 1.0
        }
    }

    func stop() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        queuePlayer?.pause()
        player?.pause()
        looper = nil
        queuePlayer = nil
        player = nil
        avPlayerLayer.player = nil
        isReversed = false
    }

    deinit { stop() }
}

// MARK: - UIOpacityModifier (for UI layer transparency)

struct UIOpacityModifier: ViewModifier {
    @ObservedObject private var manager = AppBackgroundManager.shared

    func body(content: Content) -> some View {
        content
            .opacity(manager.settings.type == .none ? 1.0 : manager.settings.uiOpacity)
    }
}

extension View {
    func appUIOpacity() -> some View {
        modifier(UIOpacityModifier())
    }
}
