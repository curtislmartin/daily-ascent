# App Icon Redesign — Design Spec

**Date:** 2026-03-16
**Status:** Approved for implementation

---

## Overview

Replace the current ruler/scale icon with a bold abstract arc mark on a deep indigo background. The goal is a striking, distinctive icon that reads clearly at all sizes without relying on fitness clichés.

---

## Design

**Background:** Solid deep indigo `#1A1040`

**Shape:** A single arc — approximately 120° sweep, travelling from bottom-left to top-right. Stroke only (no fill). Rounded linecaps. Stroke weight ~90px at 1024px canvas (scales proportionally).

**Arc colour:** Warm off-white `#F0EEF8`

**Composition:** Arc centred on canvas, sized to occupy ~60% of the canvas width. Equal breathing room on all sides.

**No gradients, no glow, no secondary elements.**

---

## Sizes Required

All sizes are generated from the SVG source:

| File | Size |
|---|---|
| icon-1024.png | 1024×1024 |
| icon-180.png | 180×180 |
| icon-167.png | 167×167 |
| icon-152.png | 152×152 |
| icon-120.png | 120×120 |
| icon-87.png | 87×87 |
| icon-80.png | 80×80 |
| icon-76.png | 76×76 |
| icon-60.png | 60×60 |
| icon-58.png | 58×58 |
| icon-40.png | 40×40 |
| icon-29.png | 29×29 |
| icon-20.png | 20×20 |

---

## Implementation

1. Update `icon/inch-icon.svg` with the new design
2. Export all PNG sizes using `rsvg-convert` or `sips`
3. Replace files in `inch/inch/Assets.xcassets/AppIcon.appiconset/`
4. Verify in Xcode that all slots are filled

---

## Rejected / Parked Alternatives

These were proposed during brainstorming but not pursued. Revisit if the arc design doesn't work out.

### Option 2 — Stacked Bars on Forest Green
Three progressively taller vertical bars — minimal, abstract, reads as both progress and strength.
- Background: deep forest `#0D3B2E`
- Bars: near-white, equal spacing, heights roughly 50% / 70% / 90% of canvas

### Option 3 — Diamond on Rich Black
A solid geometric diamond (rotated square) with a fine inner cut. Premium feel, zero fitness cliché.
- Background: `#0A0A0F`
- Shape: electric blue `#4F7CFF` or warm gold `#E8B84B`
