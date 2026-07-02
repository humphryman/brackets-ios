//
//  ChipCarousel.swift
//  Brackets
//

import SwiftUI

private struct CarouselContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CarouselContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Horizontally scrollable chip row with overflow chevron buttons. Generic over any
/// Hashable item; `label` provides the chip text (and scroll id).
struct ChipCarousel<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selected: Item?

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var leadingIndex: Int = 0

    private var isOverflowing: Bool { contentWidth > viewportWidth + 1 }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 6) {
                if isOverflowing {
                    arrow("chevron.left") { step(-1, proxy) }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        ForEach(items, id: \.self) { item in
                            chipButton(item).id(label(item))
                        }
                    }
                    .padding(.horizontal, 2)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CarouselContentWidthKey.self, value: geo.size.width)
                        }
                    )
                }
                .onPreferenceChange(CarouselContentWidthKey.self) { contentWidth = $0 }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CarouselContainerWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(CarouselContainerWidthKey.self) { viewportWidth = $0 }

                if isOverflowing {
                    arrow("chevron.right") { step(1, proxy) }
                }
            }
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .onChange(of: items) { leadingIndex = 0 }
        }
        .frame(height: 44)
    }

    /// Scroll the row by roughly one viewport of chips in `direction` (+1 right, -1 left).
    private func step(_ direction: Int, _ proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        let avg = contentWidth > 0 ? contentWidth / CGFloat(items.count) : 90
        let page = max(1, Int((viewportWidth / avg).rounded(.down)))
        leadingIndex = min(max(0, leadingIndex + direction * page), items.count - 1)
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(label(items[leadingIndex]), anchor: .leading)
        }
    }

    private func chipButton(_ item: Item) -> some View {
        let isSelected = selected == item
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = item }
        } label: {
            Text(label(item))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.primaryText : Color(white: 0.83))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(isSelected ? Color.clear : Color(white: 0.08)))
                .overlay(Capsule().strokeBorder(AppTheme.Colors.accent, lineWidth: isSelected ? 2.5 : 0))
        }
        .buttonStyle(.plain)
    }

    private func arrow(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(white: 0.83))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(white: 0.14)))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Chip carousel") {
    struct Wrap: View {
        @State var sel: String? = "Grupo 1"
        var items: [String] {
            (1...13).map { "Grupo \($0)" } + ["Playoffs", "Playoffs 2", "Playoffs 3"]
        }
        var body: some View {
            ChipCarousel(items: items, label: { $0 }, selected: $sel)
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
