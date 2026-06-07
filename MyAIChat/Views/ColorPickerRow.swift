//
//  ColorPickerRow.swift
//  MyAIChat
//
//  Reusable color picker row used inside element editor views.
//

import SwiftUI

struct ColorPickerRow: View {
    let label: String
    @Binding var customColor: CustomColor

    var body: some View {
        ColorPicker(label, selection: colorBinding, supportsOpacity: true)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { customColor.swiftUIColor },
            set: { newColor in
                customColor = CustomColor(newColor)
            }
        )
    }
}

// MARK: - Slider Row

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value, specifier: step < 1 ? "%.1f" : "%.0f")\(unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 42, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Font Weight Picker Row

struct FontWeightPickerRow: View {
    let label: String
    @Binding var weight: String

    private let weights = ["ultralight", "thin", "light", "regular",
                           "medium", "semibold", "bold", "heavy", "black"]

    var body: some View {
        Picker(label, selection: $weight) {
            ForEach(weights, id: \.self) { w in
                Text(w.capitalized).tag(w)
            }
        }
    }
}
