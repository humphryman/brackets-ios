# Tournament List Gender Tabs — Design

**Date:** 2026-07-01
**Files:** `Brackets/TournamentsViewModel.swift`, `Brackets/ContentView.swift`. No model/API changes.

## Goal

On the tournament list, filter tournaments by "rama" (Varonil / Femenil) using pill-style
tabs (mockup #29), shown only when both genders are present. Restyle the existing
always-visible segmented gender control into two independent pills and hide it when there's a
single gender (or none).

## Current state

`ContentView` already shows a `GenderSelectorView` (segmented control, shared background +
sliding `matchedGeometryEffect` pill, always both genders). `TournamentsViewModel` has
`selectedGender: Gender = .male` and `filteredTournaments = tournaments.filter { $0.gender == nil || $0.gender == selectedGender }`.
`Gender` is `.male` ("Varonil") / `.female` ("Femenil").

## 1. View model (`TournamentsViewModel`)

- Add `availableGenders: [Gender]` — the distinct **non-nil** genders present in `tournaments`,
  in fixed order `[.male, .female]` (filter `Gender.allCases` to those with ≥1 tournament):

  ```swift
  var availableGenders: [Gender] {
      Gender.allCases.filter { g in tournaments.contains { $0.gender == g } }
  }
  ```

- Add `showsGenderTabs: Bool { availableGenders.count >= 2 }`.

- Update `filteredTournaments`:

  ```swift
  var filteredTournaments: [Tournament] {
      guard showsGenderTabs else { return tournaments }
      return tournaments.filter { $0.gender == nil || $0.gender == selectedGender }
  }
  ```

  So: when both genders exist, filter by the selected tab (gender-less tournaments appear under
  either tab); when only one gender (or all gender-less), show every tournament.

- `selectedGender` keeps its `.male` default. When tabs show, both genders exist so `.male`
  ("Varonil") is a valid default and starts selected (matching the mockup). When tabs are
  hidden, `filteredTournaments` ignores `selectedGender`, so the default is harmless.

## 2. `ContentView`

Render the selector only when tabs apply:

```swift
if viewModel.showsGenderTabs {
    GenderSelectorView(selectedGender: $viewModel.selectedGender, genders: viewModel.availableGenders)
        .padding(.horizontal, AppTheme.Layout.extraLarge)
}
```

When hidden, `tournamentsContent` renders directly below "Selecciona una categoría" with no gap
from a missing selector (the surrounding `VStack` spacing handles it).

## 3. `GenderSelectorView` restyle (mockup #29)

Replace the segmented control with two independent capsule pills, left-aligned:

```swift
struct GenderSelectorView: View {
    @Binding var selectedGender: Gender
    var genders: [Gender] = Gender.allCases

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(genders, id: \.self) { gender in
                let isSelected = selectedGender == gender
                Button {
                    withAnimation(AppTheme.Animation.spring) { selectedGender = gender }
                } label: {
                    Text(gender.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.Colors.accentText : AppTheme.Colors.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isSelected ? AppTheme.Colors.accent : Color(white: 0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}
```

- Selected → accent fill + `accentText` (black); unselected → `Color(white: 0.15)` fill +
  `secondaryText`. Left-aligned via the trailing `Spacer`. Drops the shared background and
  `matchedGeometryEffect`.

## Scope

- `TournamentsViewModel.swift`: `availableGenders`, `showsGenderTabs`, `filteredTournaments` update.
- `ContentView.swift`: conditional render of the selector + restyled `GenderSelectorView` (now
  taking a `genders` list).
- Unchanged: tournament card, loading/empty/error states, navigation, all other views.

## Out of scope

- No API/model changes (uses existing `Tournament.gender`).
- No persistence of the selected tab across launches.
- No change to how gender-less tournaments are shown beyond the filter rule above (they appear
  under whichever tab is selected, as today).
