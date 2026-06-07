//
//  BackgroundSettingsView.swift
//  MyAIChat
//
//  Full-featured background settings screen.
//  Accessible from SettingsView.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BackgroundSettingsView: View {
    @ObservedObject private var manager = AppBackgroundManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker  = false
    @State private var pickerConfig     = PHPickerConfig()
    @State private var photoPickerItem: PhotosPickerItem? = nil

    // Filter for picker — updated when user taps a type button
    @State private var allowedTypes: [PHPickerFilter] = [.images, .videos, .livePhotos]

    private let thumbSize: CGFloat = 80

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                typeSection
                mediaPickerSection
                loopSection
                overlaySection
                uiSection
                resetSection
            }
            .navigationTitle("Фон приложения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section("Предпросмотр") {
            ZStack {
                // Background media thumbnail
                if manager.settings.type != .none, let img = manager.backgroundImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .overlay(dimBlurOverlay)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGroupedBackground))
                        .frame(height: 180)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("Нет фона")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                }

                // Sample UI overlay
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.85))
                            .frame(width: 160, height: 32)
                            .overlay(Text("Привет! 👋").font(.caption))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .opacity(manager.settings.type == .none ? 0 : manager.settings.uiOpacity)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    @ViewBuilder
    private var dimBlurOverlay: some View {
        ZStack {
            if manager.settings.blurRadius > 0 {
                Color.clear
                    .background(.ultraThinMaterial)
                    .opacity(min(manager.settings.blurRadius / 30.0, 1.0))
            }
            if manager.settings.dimAmount > 0 {
                Color.black.opacity(manager.settings.dimAmount)
            }
        }
    }

    // MARK: - Type Selection

    private var typeSection: some View {
        Section {
            HStack(spacing: 0) {
                ForEach(BackgroundType.allCases, id: \.self) { type in
                    Button {
                        if type == .none {
                            manager.clearBackground()
                        } else {
                            manager.settings.type = type
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: typeIcon(type))
                                .font(.system(size: 18, weight: .medium))
                            Text(type.displayName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundColor(manager.settings.type == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            manager.settings.type == type
                                ? Color.accentColor
                                : Color(.secondarySystemGroupedBackground)
                        )
                    }
                    .buttonStyle(.plain)

                    if type != BackgroundType.allCases.last {
                        Divider()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Тип фона")
        }
    }

    // MARK: - Media Picker

    @ViewBuilder
    private var mediaPickerSection: some View {
        if manager.settings.type != .none {
            Section {
                PhotosPicker(
                    selection: $photoPickerItem,
                    matching: photoFilter,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 20))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.backgroundFileURL != nil ? "Заменить медиафайл" : "Выбрать из галереи")
                                .foregroundColor(.primary)
                            if manager.isImporting {
                                Text("Импортируется…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if manager.backgroundFileURL != nil {
                                Text(manager.backgroundFileURL?.lastPathComponent ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if manager.isImporting {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.tertiaryLabel)
                        }
                    }
                }
                .onChange(of: photoPickerItem) { newItem in
                    guard let item = newItem else { return }
                    Task {
                        await manager.importMedia(from: .success([item]))
                        photoPickerItem = nil
                    }
                }

                // Content mode
                Picker("Режим заливки", selection: $manager.settings.contentMode) {
                    Text("Заполнить").tag("fill")
                    Text("Вписать").tag("fit")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Медиафайл")
            } footer: {
                switch manager.settings.type {
                case .gif:   Text("Поддерживаются анимированные GIF из Фото.")
                case .video: Text("Видео будет воспроизводиться в фоне без звука.")
                case .livePhoto: Text("Живое фото воспроизводится как видеопетля.")
                default:     Text("Выберите изображение из вашей галереи.")
                }
            }
        }
    }

    private var photoFilter: PHPickerFilter {
        switch manager.settings.type {
        case .image:      return .images
        case .gif:        return .images
        case .video:      return .videos
        case .livePhoto:  return .livePhotos
        case .none:       return .images
        }
    }

    // MARK: - Loop Mode

    @ViewBuilder
    private var loopSection: some View {
        if manager.settings.type == .gif || manager.settings.type == .video || manager.settings.type == .livePhoto {
            Section("Зацикливание") {
                ForEach(BackgroundLoopMode.allCases, id: \.self) { mode in
                    Button {
                        manager.settings.loopMode = mode
                    } label: {
                        HStack {
                            Image(systemName: loopIcon(mode))
                                .foregroundColor(.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                Text(loopDescription(mode))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if manager.settings.loopMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overlay (Dim + Blur)

    private var overlaySection: some View {
        Section {
            VStack(spacing: 16) {
                // Dimness
                VStack(spacing: 6) {
                    HStack {
                        Label("Затемнение", systemImage: "moon.fill")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(manager.settings.dimAmount * 100))%")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(manager.settings.dimAmount > 0 ? .accentColor : .secondary)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "sun.max")
                            .foregroundColor(.secondary)
                        Slider(value: $manager.settings.dimAmount, in: 0...0.9, step: 0.05)
                        Image(systemName: "moon.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Blur
                VStack(spacing: 6) {
                    HStack {
                        Label("Размытие", systemImage: "camera.filters")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(manager.settings.blurRadius))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(manager.settings.blurRadius > 0 ? .accentColor : .secondary)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Slider(value: $manager.settings.blurRadius, in: 0...30, step: 1)
                        Image(systemName: "aqi.high")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Наложение")
        } footer: {
            Text("Затемнение и размытие накладываются поверх фона.")
        }
    }

    // MARK: - UI Opacity

    private var uiSection: some View {
        Section {
            VStack(spacing: 6) {
                HStack {
                    Label("Прозрачность UI", systemImage: "square.stack.3d.up")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(manager.settings.uiOpacity * 100))%")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(manager.settings.uiOpacity < 1.0 ? .accentColor : .secondary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "square.dashed")
                        .foregroundColor(.secondary)
                    Slider(value: $manager.settings.uiOpacity, in: 0.2...1.0, step: 0.05)
                    Image(systemName: "square.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Интерфейс")
        } footer: {
            Text("Изменяет прозрачность всех элементов UI поверх фона. 100% — полностью непрозрачно.")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                manager.clearBackground()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Убрать фон")
                }
            }
            .disabled(manager.settings.type == .none)
        }
    }

    // MARK: - Helpers

    private func typeIcon(_ type: BackgroundType) -> String {
        switch type {
        case .none:      return "xmark.circle"
        case .image:     return "photo"
        case .gif:       return "photo.stack"
        case .video:     return "video"
        case .livePhoto: return "livephoto"
        }
    }

    private func loopIcon(_ mode: BackgroundLoopMode) -> String {
        switch mode {
        case .loop:     return "repeat"
        case .pingPong: return "repeat.1"
        case .once:     return "play.fill"
        }
    }

    private func loopDescription(_ mode: BackgroundLoopMode) -> String {
        switch mode {
        case .loop:     return "Бесконечное повторение с начала"
        case .pingPong: return "Вперёд и назад, бесконечно"
        case .once:     return "Воспроизвести один раз"
        }
    }
}

#Preview {
    BackgroundSettingsView()
}
