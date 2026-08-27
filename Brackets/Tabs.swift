//
//  Tabs.swift
//  Brackets
//

import SwiftUI

private struct TabsContentWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct TabsViewportWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Underlined tab bar from the Figma Design System (tab element, node `64:27`).
///
/// Tabs hug their labels and sit left-aligned on a continuous `gray500` rail that runs
/// the full width of the bar, past the last tab. The selected tab overlays a 2pt `sky900`
/// segment on that rail and turns its label white; the rest stay `gray400`.
///
/// When the tabs are wider than the bar they scroll horizontally, and selecting one
/// brings it into view. The rail stays put underneath.
///
/// Place it **full width**, with no horizontal padding from the parent — the bar applies
/// its own `contentInset`. The leading margin is always kept. The trailing one is dropped
/// only when the tabs genuinely do not fit, so an overflowing tab is sliced by the screen
/// edge and it becomes obvious there is more to scroll; when they fit, both margins hold
/// and nothing touches the edge.
struct Tabs: View {

    /// Geometry id for the sliding indicator. Private to each instance's namespace, so
    /// two tab bars on one screen never share one.
    private static let indicatorID = "tabsSelection"

    private enum Metrics {
        static let paddingH: CGFloat = 12
        static let paddingV: CGFloat = 16
        static let labelSize: CGFloat = 18
        static let rail: CGFloat = 1
        static let indicator: CGFloat = 2
        static let dot: CGFloat = 6
        static let dotSpacing: CGFloat = 6
    }

    let segments: [String]
    @Binding var selection: Int
    /// Optional leading dot per tab — used for the live-games filter, which needs a
    /// marker the Figma tab does not define.
    private let dots: [Color?]
    /// Leading and trailing inset on the scrolling tabs, so the first one lines up with
    /// the screen's content margin while the row itself still reaches the edges.
    var contentInset: CGFloat = AppTheme.Layout.screenPadding

    @Namespace private var indicator
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    /// True only when the tabs cannot fit even after giving up the trailing margin.
    private var isOverflowing: Bool {
        viewportWidth > 0 && contentWidth > viewportWidth - contentInset + 1
    }

    /// Trailing margin, surrendered to the screen edge while scrolling.
    private var trailingInset: CGFloat {
        isOverflowing ? 0 : contentInset
    }

    init(
        segments: [String],
        selection: Binding<Int>,
        contentInset: CGFloat = AppTheme.Layout.screenPadding,
        dot: (Int) -> Color? = { _ in nil }
    ) {
        self.segments = segments
        self.dots = segments.indices.map(dot)
        self._selection = selection
        self.contentInset = contentInset
    }

    /// Drive the bar from a set of options — an enum of tabs, say — instead of an index.
    /// The binding is mapped to and from the option's position in `options`.
    init<Option: Hashable>(
        options: [Option],
        selection: Binding<Option>,
        contentInset: CGFloat = AppTheme.Layout.screenPadding,
        dot: (Option) -> Color? = { _ in nil },
        label: (Option) -> String
    ) {
        self.segments = options.map(label)
        self.dots = options.map(dot)
        self.contentInset = contentInset
        self._selection = Binding(
            get: { options.firstIndex(of: selection.wrappedValue) ?? 0 },
            set: { index in
                guard options.indices.contains(index) else { return }
                selection.wrappedValue = options[index]
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The rail runs under the tabs, past the last one, and out to the screen edge
            // whenever they overflow.
            Rectangle()
                .fill(AppTheme.Colors.gray500)
                .frame(height: Metrics.rail)
                .padding(.leading, contentInset)
                .padding(.trailing, trailingInset)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, label in
                            tab(label, dot: dots[index], isSelected: index == selection)
                                .id(index)
                                .onTapGesture {
                                    withAnimation(AppTheme.Animation.spring) {
                                        selection = index
                                    }
                                }
                        }
                    }
                    // Measured unpadded, so the overflow test never depends on the
                    // padding it decides.
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TabsContentWidthKey.self, value: geo.size.width)
                        }
                    )
                    .padding(.leading, contentInset)
                    .padding(.trailing, trailingInset)
                }
                // Only scroll when the tabs actually overflow.
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .onChange(of: selection) { _, new in
                    withAnimation(AppTheme.Animation.standard) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TabsViewportWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(TabsContentWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(TabsViewportWidthKey.self) { viewportWidth = $0 }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tab(_ label: String, dot: Color?, isSelected: Bool) -> some View {
        HStack(spacing: Metrics.dotSpacing) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: Metrics.dot, height: Metrics.dot)
            }

            Text(label)
                .font(ShareFont.condensed(.semibold, size: Metrics.labelSize))
                .foregroundStyle(isSelected ? AppTheme.Colors.primaryText : AppTheme.Colors.gray400)
                .lineLimit(1)
        }
            // Figma marks the label `whitespace-nowrap`: a tab hugs its text and scrolls
            // out of view rather than truncating.
            .fixedSize()
            .padding(.horizontal, Metrics.paddingH)
            .padding(.vertical, Metrics.paddingV)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(AppTheme.Colors.sky900)
                        .frame(height: Metrics.indicator)
                        .matchedGeometryEffect(id: Self.indicatorID, in: indicator)
                }
            }
            .contentShape(Rectangle())
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var few = 0
        @State private var many = 1

        var body: some View {
            VStack(alignment: .leading, spacing: 40) {
                Tabs(segments: ["Próximos", "Resultados"], selection: $few)

                Tabs(
                    segments: ["Campeón", "Ranking final", "Grupos", "Clasificación"],
                    selection: $many
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
            .background(AppTheme.Colors.background)
        }
    }

    return PreviewHost().preferredColorScheme(.dark)
}
