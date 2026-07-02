# Tournament List Gender Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Filter the tournament list by Varonil/Femenil with pill tabs shown only when both genders are present.

**Architecture:** Add `availableGenders`/`showsGenderTabs` to `TournamentsViewModel` and gate `filteredTournaments` on them; in `ContentView`, render the gender selector only when tabs apply and restyle it into two independent capsule pills.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, `AppTheme` tokens.

**Branch:** independent — branch off `main`.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** + inspect the tournament list / `#Preview`.
- Dark mode only; UI text Spanish (`Gender.displayName` → "Varonil"/"Femenil").
- Tabs show only when `availableGenders.count >= 2`; otherwise show all tournaments (no filter).
- Pill style: selected = `AppTheme.Colors.accent` fill + `accentText`; unselected = `Color(white: 0.15)` fill + `secondaryText`; left-aligned.
- Do **not** `git commit` unless authorized; commit steps are for completeness.
- SourceKit cross-file "cannot find X in scope" errors are false positives; ignore them.

---

## File Structure

- **Modify `Brackets/TournamentsViewModel.swift`:** `availableGenders`, `showsGenderTabs`, `filteredTournaments`.
- **Modify `Brackets/ContentView.swift`:** conditional render of the selector + restyled `GenderSelectorView(selectedGender:genders:)`.

---

### Task 1: View model — available genders + gated filter

**Files:**
- Modify: `Brackets/TournamentsViewModel.swift`

**Interfaces:**
- Consumes: `tournaments: [Tournament]`, `selectedGender: Gender`, `Tournament.gender: Gender?`, `Gender.allCases`.
- Produces: `availableGenders: [Gender]`, `showsGenderTabs: Bool`; updated `filteredTournaments`.

- [ ] **Step 1: Add `availableGenders` and `showsGenderTabs`**

In `TournamentsViewModel`, add after the `selectedGender` property:

```swift
    var availableGenders: [Gender] {
        Gender.allCases.filter { gender in tournaments.contains { $0.gender == gender } }
    }

    var showsGenderTabs: Bool {
        availableGenders.count >= 2
    }
```

- [ ] **Step 2: Gate `filteredTournaments` on `showsGenderTabs`**

Replace the existing `filteredTournaments`:

```swift
    var filteredTournaments: [Tournament] {
        tournaments.filter { $0.gender == nil || $0.gender == selectedGender }
    }
```

with:

```swift
    var filteredTournaments: [Tournament] {
        guard showsGenderTabs else { return tournaments }
        return tournaments.filter { $0.gender == nil || $0.gender == selectedGender }
    }
```

- [ ] **Step 3: Build**

Run: **⌘B**. Expected: builds. Behavior: when both genders exist, filtering is unchanged from before; when only one gender (or all gender-less), `filteredTournaments` now returns every tournament (previously a female-only league could be hidden by the `.male` default). The always-visible selector is still shown (fixed in Task 2).

- [ ] **Step 4: Commit** (only if authorized)

```bash
git add Brackets/TournamentsViewModel.swift
git commit -m "Add availableGenders/showsGenderTabs and gate tournament filter"
```

---

### Task 2: ContentView — conditional pill tabs

**Files:**
- Modify: `Brackets/ContentView.swift`

**Interfaces:**
- Consumes: `viewModel.showsGenderTabs`, `viewModel.availableGenders`, `viewModel.selectedGender` (Task 1).
- Produces: conditional `GenderSelectorView`; `GenderSelectorView(selectedGender:genders:)` restyled to independent capsule pills.

- [ ] **Step 1: Render the selector only when tabs apply**

Replace the current usage:

```swift
                            GenderSelectorView(selectedGender: $viewModel.selectedGender)
                                .padding(.horizontal, AppTheme.Layout.extraLarge)
```

with:

```swift
                            if viewModel.showsGenderTabs {
                                GenderSelectorView(
                                    selectedGender: $viewModel.selectedGender,
                                    genders: viewModel.availableGenders
                                )
                                .padding(.horizontal, AppTheme.Layout.extraLarge)
                            }
```

- [ ] **Step 2: Restyle `GenderSelectorView` to independent pills**

Replace the entire `struct GenderSelectorView: View { … }` with:

```swift
struct GenderSelectorView: View {
    @Binding var selectedGender: Gender
    var genders: [Gender] = Gender.allCases

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(genders, id: \.self) { gender in
                let isSelected = selectedGender == gender
                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        selectedGender = gender
                    }
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

(Removes the `@Namespace`/`matchedGeometryEffect` sliding pill and the shared rounded background. The `genders` param defaults to `Gender.allCases` so any other caller/preview still compiles.)

- [ ] **Step 3: Build and verify in Xcode**

Run: **⌘B**, open the tournament list (pick a league).
Expected: builds. When the league has **both** Varonil and Femenil tournaments, two pills show (Varonil selected/lime, Femenil dark), tapping switches the filtered list. When the league has only one gender (or none), **no pills** show and all its tournaments are listed. Gender-less tournaments appear under the selected tab when tabs are shown.

- [ ] **Step 4: Commit** (only if authorized)

```bash
git add Brackets/ContentView.swift
git commit -m "Show gender pill tabs only when both ramas exist; restyle to pills"
```

---

## Self-Review

**Spec coverage:**
- `availableGenders` (non-nil, ordered) + `showsGenderTabs` (≥2) → Task 1 Step 1. ✔
- `filteredTournaments` gated (all when hidden, filter when shown) → Task 1 Step 2. ✔
- Conditional render of selector → Task 2 Step 1. ✔
- Two-pill restyle (selected lime/black, unselected dark/gray, left-aligned) → Task 2 Step 2. ✔
- Default `.male`/Varonil preserved (unchanged) → not modified. ✔
- Gender-less tournaments shown under selected tab (filter rule unchanged) → Task 1 Step 2. ✔

**Placeholder scan:** No TBD/TODO; every step has complete code.

**Type consistency:** `availableGenders: [Gender]`, `showsGenderTabs: Bool`, `filteredTournaments: [Tournament]`, `GenderSelectorView(selectedGender:genders:)` are consistent across tasks; the `genders` default keeps existing callers valid.
