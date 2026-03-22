# DemographicTagsView Redesign

**Goal:** Replace horizontal-scroll chips with full-width stacked selection cards, improving tap targets and visual consistency with the rest of onboarding.

**Tech Stack:** SwiftUI, InchShared (DemographicProfile)

---

## Scope

`DemographicTagsView.swift` only. No changes to data model, view model, or any other onboarding screen.

---

## Design

### Navigation

Retain the existing `.navigationTitle("Profile")` and `.navigationBarTitleDisplayMode(.large)` unchanged. The inline header content sits below the large title.

### Header

Replace the existing header copy with:

- **Title:** "Tell us about yourself" — `.headline`, primary
- **Subtitle:** "All optional — tap Continue to skip." — `.subheadline`, `.secondary`

### Layout

Single scrollable `ScrollView`. The outer `VStack(alignment: .leading, spacing: 24)` retains the existing `.padding(.horizontal)` padding. Cards sit inside this padded container — they do not bleed to screen edges. The 24pt spacing applies uniformly between the header, all sections, and the Continue button. Continue button scrolls with the content (not fixed). No pagination.

Each section:
- Section label: `.caption`, `.textCase(.uppercase)`, `.secondary`, 6pt bottom margin (changed from `.subheadline` / `.fontWeight(.medium)` used by the existing `PickerSection`)
- Cards stacked vertically with 6pt gap inside a `VStack(spacing: 6)`

### Card Component

Extract each option card to a private subview with this interface:

```swift
private struct DemographicOptionCard: View {
    let label: String
    let subtitle: String?   // nil for Age, Height, Biological sex sections
    let isSelected: Bool
    let onTap: () -> Void
}
```

Internal layout: `VStack(alignment: .leading, spacing: 2)` containing the label `Text` and, when `subtitle` is non-nil, the subtitle `Text`. Padded `12pt` vertical, `14pt` horizontal.

Visual chrome — matches `ExerciseSelectionCard` exactly:

| State | Background | Border |
|---|---|---|
| Unselected | `Color(.secondarySystemGroupedBackground)` | `Color.clear` |
| Selected | `Color.accentColor.opacity(0.08)` | `Color.accentColor`, 1.5pt |

Apply `.background`, `.overlay`, and `.contentShape` to the inner content `VStack` (the button label), not to the `Button` itself — matching `ExerciseSelectionCard`'s pattern where these modifiers sit on the `HStack`:

```swift
Button(action: onTap) {
    VStack(alignment: .leading, spacing: 2) { ... }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.animation(.easeInOut(duration: 0.15), value: isSelected)
```

`.background` takes a plain `Color` (no `in:` shape argument), matching `ExerciseSelectionCard`. This is correct — the border overlay handles the visual rounding; no `.clipShape` is needed.

Typography:
- Label: `.body`, `.fontWeight(.medium)`, `.primary`
- Subtitle: `.caption2`, `.secondary`

Tapping a selected card deselects it (sets the section's `@State` back to `nil`), matching existing chip toggle behaviour.

### Sections

**Age** — label only (6 options):
- Under 18
- 18–29
- 30–39
- 40–49
- 50–59
- 60+

**Height** — label only (5 options, strings unchanged from existing code):
- Under 160cm
- 160–170cm
- 171–180cm
- 181–190cm
- Over 190cm

**Biological sex** — label only (3 options):
- Male
- Female
- Prefer not to say

**Activity level** — label + subtitle (3 options). Replace the existing `activityOptions: [String]` with a typed tuple array so each option carries its subtitle:

```swift
private let activityOptions: [(label: String, subtitle: String)] = [
    ("Beginner",     "New to training"),
    ("Intermediate", "2–3× per week"),
    ("Advanced",     "Training 2+ years"),
]
```

Iterate with `ForEach(activityOptions, id: \.label)` and pass `subtitle: option.subtitle` to `DemographicOptionCard`. The `VStack(spacing: 2)` inside the card provides the 2pt gap between label and subtitle; no additional `.padding(.top, 2)` is needed.

### CTA

Single `.borderedProminent` Continue button, full-width, pinned to bottom of scroll content (matching `EnrolmentView`). The Skip toolbar button is removed — the subtitle "All optional — tap Continue to skip." provides the skip affordance.

---

## What Is Not In Scope

- No changes to `DemographicProfile`, `DemographicTagsViewModel`, or any other type
- No changes to other onboarding screens
- No new animations or transitions
- No changes to how selections are persisted
