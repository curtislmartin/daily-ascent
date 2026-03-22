# DemographicTagsView Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace horizontal-scroll chips in `DemographicTagsView` with full-width stacked selection cards, improving tap targets and matching `ExerciseSelectionCard`'s visual chrome.

**Architecture:** Single-file rewrite. `PickerSection` is replaced by a new `DemographicOptionCard` private subview that uses the same `background`/`overlay(strokeBorder)` pattern as `ExerciseSelectionCard`. `DemographicTagsView`'s body is updated to iterate options using `ForEach` + `DemographicOptionCard`. No changes outside this file.

**Tech Stack:** SwiftUI, iOS 18, Swift 6.2

---

## Chunk 1: Rewrite DemographicTagsView

### Task 1: Replace PickerSection with DemographicOptionCard

**Files:**
- Modify: `inch/inch/Features/Onboarding/DemographicTagsView.swift`

No unit tests — this is a pure SwiftUI view with no extractable logic (the toggle is one line). Verify via `#Preview`.

**Reference files (read before implementing):**
- `inch/inch/Features/Onboarding/ExerciseSelectionCard.swift` — card chrome pattern to match
- `docs/superpowers/specs/2026-03-22-demographic-tags-redesign.md` — full spec

---

- [ ] **Step 1: Read the current file and reference files**

Read these three files before touching anything:
```
inch/inch/Features/Onboarding/DemographicTagsView.swift
inch/inch/Features/Onboarding/ExerciseSelectionCard.swift
docs/superpowers/specs/2026-03-22-demographic-tags-redesign.md
```

---

- [ ] **Step 2: Replace the entire file contents**

Write `inch/inch/Features/Onboarding/DemographicTagsView.swift` with the following:

```swift
import SwiftUI

struct DemographicTagsView: View {
    let onComplete: (String?, String?, String?, String?) -> Void

    @State private var ageRange: String? = nil
    @State private var heightRange: String? = nil
    @State private var biologicalSex: String? = nil
    @State private var activityLevel: String? = nil

    private let ageOptions = ["Under 18", "18–29", "30–39", "40–49", "50–59", "60+"]
    private let heightOptions = ["Under 160cm", "160–170cm", "171–180cm", "181–190cm", "Over 190cm"]
    private let sexOptions = ["Male", "Female", "Prefer not to say"]
    private let activityOptions: [(label: String, subtitle: String)] = [
        ("Beginner",     "New to training"),
        ("Intermediate", "2–3× per week"),
        ("Advanced",     "Training 2+ years"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: "Age") {
                    ForEach(ageOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: ageRange == option
                        ) {
                            ageRange = ageRange == option ? nil : option
                        }
                    }
                }

                section(title: "Height") {
                    ForEach(heightOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: heightRange == option
                        ) {
                            heightRange = heightRange == option ? nil : option
                        }
                    }
                }

                section(title: "Biological sex") {
                    ForEach(sexOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: biologicalSex == option
                        ) {
                            biologicalSex = biologicalSex == option ? nil : option
                        }
                    }
                }

                section(title: "Activity level") {
                    ForEach(activityOptions, id: \.label) { option in
                        DemographicOptionCard(
                            label: option.label,
                            subtitle: option.subtitle,
                            isSelected: activityLevel == option.label
                        ) {
                            activityLevel = activityLevel == option.label ? nil : option.label
                        }
                    }
                }

                Button {
                    onComplete(ageRange, heightRange, biologicalSex, activityLevel)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tell us about yourself")
                .font(.headline)
            Text("All optional — tap Continue to skip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder cards: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            cards()
        }
    }
}

private struct DemographicOptionCard: View {
    let label: String
    let subtitle: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    NavigationStack {
        DemographicTagsView { _, _, _, _ in }
    }
}
```

---

- [ ] **Step 3: Build and verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  | xcpretty
```

Expected: `** BUILD SUCCEEDED **`

If the build fails, fix the error before proceeding.

---

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Onboarding/DemographicTagsView.swift
git commit -m "feat: redesign DemographicTagsView with full-width selection cards"
```
