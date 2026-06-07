//
//  LiquidGlassModifier.swift
//  MyAIChat
//
//  Liquid Glass visual style — frosted glass with iridescent shimmer,
//  specular highlight, and subtle inner glow.
//  Applied as a ViewModifier and exposed via View extension.
//

import SwiftUI

// MARK: - Liquid Glass Modifier

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: Double
    var intensity: Double    // 0…1, controls blur/opacity strength
    @State private var shimmerOffset: CGFloat = -1.0

    init(cornerRadius: Double = 16, intensity: Double = 1.0) {
        self.cornerRadius = cornerRadius
        self.intensity    = max(0, min(1, intensity))
    }

    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(shimmerOverlay)
            .overlay(borderOverlay)
            .shadow(color: .white.opacity(0.18 * intensity), radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.18 * intensity), radius: 12 * intensity, x: 0, y: 6)
            .onAppear { startShimmer() }
    }

    // MARK: Frosted glass base

    private var glassBackground: some View {
        ZStack {
            // Blur layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // Tinted overlay for colour depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22 * intensity),
                            .white.opacity(0.08 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle iridescent tint
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 0.55, green: 0.85, blue: 1.0).opacity(0.12 * intensity),
                            Color(red: 0.85, green: 0.60, blue: 1.0).opacity(0.10 * intensity),
                            Color(red: 1.00, green: 0.75, blue: 0.55).opacity(0.08 * intensity),
                            Color(red: 0.55, green: 0.85, blue: 1.0).opacity(0.12 * intensity)
                        ],
                        center: .center
                    )
                )
        }
    }

    // MARK: Animated shimmer

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.30 * intensity),
                            .white.opacity(0.50 * intensity),
                            .white.opacity(0.30 * intensity),
                            .clear
                        ],
                        startPoint: .init(x: shimmerOffset - 0.3, y: 0),
                        endPoint:   .init(x: shimmerOffset + 0.3, y: 1)
                    )
                )
                .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
    }

    // MARK: Specular border

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.70 * intensity),
                        .white.opacity(0.15 * intensity),
                        .white.opacity(0.05 * intensity),
                        .white.opacity(0.40 * intensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.0
            )
    }

    // MARK: Animation

    private func startShimmer() {
        shimmerOffset = -1.0
        withAnimation(
            .easeInOut(duration: 3.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 2.0
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the Liquid Glass frosted-glass style.
    /// - Parameters:
    ///   - cornerRadius: Shape rounding (default 16).
    ///   - intensity: Effect strength 0…1 (default 1).
    func liquidGlass(cornerRadius: Double = 16, intensity: Double = 1.0) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, intensity: intensity))
    }
}
