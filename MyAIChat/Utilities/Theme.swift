//
//  Theme.swift
//  MyAIChat
//
//  Centralized design tokens (colors, corner radius, spacing, shadow).
//  Uses semantic system colors so light/dark mode is supported automatically.
//

import SwiftUI

/// App-wide design tokens. Keep visual constants here so views stay consistent
/// and the look can be tweaked in one place.
enum Theme {

    // MARK: Colors

    enum Colors {
        /// Brand / interactive accent color.
        static let accent = Color.accentColor

        /// Background for messages sent by the user.
        static let userBubble = Color.accentColor
        /// Background for messages from the assistant (adapts to light/dark).
        static let assistantBubble = Color(.secondarySystemBackground)

        /// Text color inside user bubbles.
        static let userText = Color.white
        /// Text color inside assistant bubbles.
        static let assistantText = Color.primary

        /// Primary screen background.
        static let background = Color(.systemBackground)
        /// Background behind the bottom input bar.
        static let inputBarBackground = Color(.systemBackground)
        /// Fill of the rounded input field.
        static let inputFieldBackground = Color(.secondarySystemBackground)

        /// Secondary / muted text (e.g. status labels, placeholders).
        static let secondaryText = Color.secondary
        /// Hairline separators / borders.
        static let separator = Color(.separator)
        /// Subtle shadow color for elevation.
        static let shadow = Color.black.opacity(0.08)
    }

    // MARK: Corner radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        /// Rounding used for chat bubbles.
        static let bubble: CGFloat = 18
    }

    // MARK: Spacing

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    // MARK: Shadow

    enum Shadow {
        static let color = Colors.shadow
        static let radius: CGFloat = 4
        static let y: CGFloat = 2
    }
}
