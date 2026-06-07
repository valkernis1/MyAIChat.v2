//
//  AppBackgroundManager.swift
//  MyAIChat
//
//  Manages the global app background: static image, GIF, video, or Live Photo.
//  Supports loop modes, dim/blur/UI-opacity overlay, persists via UserDefaults + app sandbox.
//

import SwiftUI
import Combine
import PhotosUI
import AVFoundation

// MARK: - Background Type

enum BackgroundType: String, Codable, CaseIterable {
    case none      = "none"
    case image     = "image"
    case gif       = "gif"
    case video     = "video"
    case livePhoto = "livePhoto"

    var displayName: String {
        switch self {
        case .none:      return "Нет"
        case .image:     return "Изображение"
        case .gif:       return "GIF"
        case .video:     return "Видео"
        case .livePhoto: return "Live Photo"
        }
    }
}

// MARK: - Loop Mode

enum BackgroundLoopMode: String, Codable, CaseIterable {
    case loop      = "loop"
    case pingPong  = "pingPong"
    case once      = "once"

    var displayName: String {
        switch self {
        case .loop:     return "Зацикленно"
        case .pingPong: return "Туда-обратно"
        case .once:     return "Один раз"
        }
    }
}

// MARK: - Background Settings (Codable for persistence)

struct AppBackgroundSettings: Codable, Equatable {
    var type: BackgroundType        = .none
    var loopMode: BackgroundLoopMode = .loop
    var dimAmount: Double           = 0.0    // 0..1 darkness overlay
    var blurRadius: Double          = 0.0    // 0..30 blur
    var uiOpacity: Double           = 1.0    // UI layer opacity
    var contentMode: String         = "fill" // "fill" or "fit"

    static let `default` = AppBackgroundSettings()
}

// MARK: - Manager

@MainActor
final class AppBackgroundManager: ObservableObject {

    static let shared = AppBackgroundManager()

    // MARK: Published

    @Published var settings: AppBackgroundSettings {
        didSet { persistSettings() }
    }

    /// Resolved UIImage (for .image and .gif first-frame preview)
    @Published var backgroundImage: UIImage?

    /// URL of the media file stored in app sandbox
    @Published var backgroundFileURL: URL?

    /// True while importing
    @Published var isImporting: Bool = false

    // MARK: Private

    private let settingsKey = "appBackground.settings.v1"
    private let fileNameKey = "appBackground.fileName.v1"
    private let typeKey     = "appBackground.fileType.v1"

    private init() {
        // Load settings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(AppBackgroundSettings.self, from: data) {
            settings = saved
        } else {
            settings = .default
        }
        // Load file reference
        loadSavedFile()
    }

    // MARK: - Import from PhotosUI

    func importMedia(from result: Result<[PhotosPickerItem], Error>) async {
        isImporting = true
        defer { isImporting = false }

        guard case .success(let items) = result, let item = items.first else { return }

        // Detect type
        let isGIF = item.supportedContentTypes.contains(.gif)
        let isVideo = item.supportedContentTypes.contains(.movie) ||
                      item.supportedContentTypes.contains(.video) ||
                      item.supportedContentTypes.contains(.mpeg4Movie) ||
                      item.supportedContentTypes.contains(.quickTimeMovie)
        let isLivePhoto = item.supportedContentTypes.contains(.livePhoto)

        if isVideo || isLivePhoto {
            await importTransferable(item: item, isLive: isLivePhoto)
        } else {
            await importImageOrGIF(item: item, isGIF: isGIF)
        }
    }

    // MARK: Import image / GIF

    private func importImageOrGIF(item: PhotosPickerItem, isGIF: Bool) async {
        if isGIF {
            if let data = try? await item.loadTransferable(type: Data.self) {
                save(data: data, ext: "gif", type: .gif)
            }
        } else {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Could be HEIC or JPEG — save as-is, display via UIImage
                save(data: data, ext: "jpg", type: .image)
            }
        }
    }

    // MARK: Import Video / Live Photo (via URL)

    private func importTransferable(item: PhotosPickerItem, isLive: Bool) async {
        // Try to load as a movie URL via transferable
        if let movie = try? await item.loadTransferable(type: VideoFileTransferable.self) {
            let destExt = isLive ? "mov" : "mp4"
            let destType: BackgroundType = isLive ? .livePhoto : .video
            copyToSandbox(url: movie.url, ext: destExt, type: destType)
        } else if let data = try? await item.loadTransferable(type: Data.self) {
            let ext = isLive ? "mov" : "mp4"
            let type: BackgroundType = isLive ? .livePhoto : .video
            save(data: data, ext: ext, type: type)
        }
    }

    // MARK: Clear background

    func clearBackground() {
        if let url = backgroundFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        backgroundFileURL = nil
        backgroundImage = nil
        settings.type = .none
        UserDefaults.standard.removeObject(forKey: fileNameKey)
        UserDefaults.standard.removeObject(forKey: typeKey)
    }

    // MARK: - Private helpers

    private func save(data: Data, ext: String, type: BackgroundType) {
        let dir = backgroundsDirectory()
        let fileName = "background.\(ext)"
        let url = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            applyNewFile(url: url, type: type)
        } catch {
            print("[AppBG] Failed to save file: \(error)")
        }
    }

    private func copyToSandbox(url: URL, ext: String, type: BackgroundType) {
        let dir = backgroundsDirectory()
        let fileName = "background.\(ext)"
        let dest = dir.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            applyNewFile(url: dest, type: type)
        } catch {
            print("[AppBG] Failed to copy: \(error)")
        }
    }

    private func applyNewFile(url: URL, type: BackgroundType) {
        backgroundFileURL = url
        settings.type = type
        UserDefaults.standard.set(url.lastPathComponent, forKey: fileNameKey)
        UserDefaults.standard.set(type.rawValue, forKey: typeKey)

        // Load preview image
        switch type {
        case .image, .livePhoto:
            if let img = UIImage(contentsOfFile: url.path) {
                backgroundImage = img
            }
        case .gif:
            if let img = UIImage(contentsOfFile: url.path) {
                backgroundImage = img
            } else if let data = try? Data(contentsOf: url),
                      let img = UIImage(data: data) {
                backgroundImage = img
            }
        case .video:
            backgroundImage = videoThumbnail(url: url)
        case .none:
            backgroundImage = nil
        }
    }

    private func loadSavedFile() {
        guard let fileName = UserDefaults.standard.string(forKey: fileNameKey),
              let rawType  = UserDefaults.standard.string(forKey: typeKey),
              let type     = BackgroundType(rawValue: rawType) else { return }

        let url = backgroundsDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        backgroundFileURL = url
        switch type {
        case .image, .livePhoto:
            backgroundImage = UIImage(contentsOfFile: url.path)
        case .gif:
            if let data = try? Data(contentsOf: url) {
                backgroundImage = UIImage(data: data)
            }
        case .video:
            backgroundImage = videoThumbnail(url: url)
        case .none:
            break
        }
    }

    private func backgroundsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("AppBackgrounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func videoThumbnail(url: URL) -> UIImage? {
        let asset    = AVAsset(url: url)
        let gen      = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        if let cgImage = try? gen.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}

// MARK: - VideoFileTransferable

struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFileTransferable(url: copy)
        }
        FileRepresentation(contentType: .quickTimeMovie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFileTransferable(url: copy)
        }
    }
}
