//
//  SegmentedController.swift
//  Brackets
//

import SwiftUI

/// Segmented controller from the Figma Design System (node `115:124`).
///
/// Two or three mutually exclusive options on a dark track. The selected segment is a
/// tinted `sky900Muted` fill with a 2pt `sky900` border and a white label; the rest are
/// plain `gray300` labels.
///
/// Sizing follows `width`: `.fill` stretches the track and splits it evenly between the
/// segments (how the "Resultado" screen uses it), `.intrinsic` sizes the track to its
/// labels.
struct SegmentedController: View {

    /// How the track claims horizontal space.
    enum Width {
        /// Span the parent's width; every segment gets an equal share.
        case fill
        /// Hug the labels.
        case intrinsic
    }

    private enum Metrics {
        static let trackPadding: CGFloat = 4
        static let trackRadius: CGFloat = 8
        static let segmentSpacing: CGFloat = 4
        static let segmentRadius: CGFloat = 6
        static let segmentPaddingH: CGFloat = 12
        static let segmentPaddingV: CGFloat = 8
        static let selectedBorder: CGFloat = 2
        static let labelSize: CGFloat = 14
    }

    /// Geometry id for the selection indicator. Private to each instance's namespace,
    /// so several controllers on one screen never share an indicator.
    private static let indicatorID = "segmentedSelection"

    let segments: [String]
    @Binding var selection: Int
    var width: Width = .fill

    @Namespace private var indicator

    init(segments: [String], selection: Binding<Int>, width: Width = .fill) {
        self.segments = segments
        self._selection = selection
        self.width = width
    }

    /// Drive the control from a set of options — an enum of tabs, say — instead of an
    /// index. The binding is mapped to and from the option's position in `options`.
    init<Option: Hashable>(
        options: [Option],
        selection: Binding<Option>,
        width: Width = .fill,
        label: (Option) -> String
    ) {
        self.segments = options.map(label)
        self.width = width
        self._selection = Binding(
            get: { options.firstIndex(of: selection.wrappedValue) ?? 0 },
            set: { index in
                guard options.indices.contains(index) else { return }
                selection.wrappedValue = options[index]
            }
        )
    }

    var body: some View {
        HStack(spacing: Metrics.segmentSpacing) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, label in
                segment(label, isSelected: index == selection) {
                    withAnimation(AppTheme.Animation.spring) {
                        selection = index
                    }
                }
            }
        }
        .padding(Metrics.trackPadding)
        .background(
            RoundedRectangle(cornerRadius: Metrics.trackRadius)
                .fill(AppTheme.Colors.gray700)
                .strokeBorder(AppTheme.Colors.gray600, lineWidth: 1)
        )
        .fixedSize(horizontal: width == .intrinsic, vertical: true)
    }

    private func segment(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: Metrics.labelSize, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.primaryText : AppTheme.Colors.gray300)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Metrics.segmentPaddingH)
                .padding(.vertical, Metrics.segmentPaddingV)
                .frame(maxWidth: width == .fill ? .infinity : nil)
                .background {
                    if isSelected {
                        // One shared indicator that slides between segments rather than a
                        // fill appearing and disappearing in place.
                        RoundedRectangle(cornerRadius: Metrics.segmentRadius)
                            .fill(AppTheme.Colors.sky900Muted)
                            .strokeBorder(AppTheme.Colors.sky900, lineWidth: Metrics.selectedBorder)
                            .matchedGeometryEffect(id: Self.indicatorID, in: indicator)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Metrics.segmentRadius))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var pair = 0
        @State private var trio = 1

        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                SegmentedController(segments: ["CHIHUAHUA A", "DURANGO A"], selection: $pair)
                SegmentedController(segments: ["Label", "Label", "Label"], selection: $trio, width: .intrinsic)
                SegmentedController(segments: ["Label", "Label", "Label"], selection: $trio)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
        }
    }

    return PreviewHost()
        .preferredColorScheme(.dark)
}
