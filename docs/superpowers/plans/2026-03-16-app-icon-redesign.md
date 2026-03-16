# App Icon Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current ruler/scale icon with a bold arc on deep indigo that reads clearly at all sizes.

**Architecture:** Update the SVG source in `icon/`, export two 1024×1024 PNGs using Node + sharp, replace both files in the Xcode asset catalog. The project's `Contents.json` uses a 2-slot universal structure (one iOS 1024px, one watchOS 1024px) — Xcode derives all smaller sizes automatically from the single universal image. No individual size exports are required.

**Tech Stack:** SVG, Node.js + sharp (globally installed — use `NODE_PATH=/opt/homebrew/lib/node_modules`)

---

## Files

| File | Change |
|---|---|
| `icon/inch-icon.svg` | Replace with new arc design |
| `inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | Replace with exported PNG |
| `inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024-watch.png` | Replace with exported PNG (same image) |

No other files change. `Contents.json` already has the correct 2-slot structure.

---

## Task 1: Update SVG and export PNGs

**Files:**
- Modify: `icon/inch-icon.svg`
- Modify: `inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Modify: `inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024-watch.png`

- [ ] **Step 1: Write the new SVG**

Replace the entire contents of `icon/inch-icon.svg` with:

```xml
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="1024" height="1024" fill="#1A1040"/>

  <!-- Arc: sweeps from bottom-left to top-right, clockwise, bowing upward -->
  <path
    d="M 220 750 A 390 390 0 0 1 780 280"
    fill="none"
    stroke="#F0EEF8"
    stroke-width="88"
    stroke-linecap="round"
  />
</svg>
```

Arc geometry: start (220, 750) is lower-left, end (780, 280) is upper-right, radius 390px, clockwise sweep (sweep-flag=1). Chord length ≈731px < diameter 780px so the arc is geometrically valid. The clockwise direction from lower-left to upper-right produces an arc that bows toward the upper-left, reading as a bold upward sweep.

- [ ] **Step 2: Ensure sharp is installed globally**

```bash
npm install -g sharp
```

Expected: installs to `/opt/homebrew/lib/node_modules/sharp`

- [ ] **Step 3: Export PNGs using Node + sharp**

Run from the repo root:

```bash
NODE_PATH=/opt/homebrew/lib/node_modules node -e "
const sharp = require('sharp');
const fs = require('fs');
const svg = fs.readFileSync('icon/inch-icon.svg');
sharp(svg).resize(1024,1024).png().toFile('inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024.png', (e) => { if(e) console.error('iOS:',e); else console.log('iOS done'); });
sharp(svg).resize(1024,1024).png().toFile('inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024-watch.png', (e) => { if(e) console.error('watch:',e); else console.log('watch done'); });
"
```

Expected output:
```
iOS done
watch done
```

- [ ] **Step 4: Visually verify the 1024px PNG**

Open `inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024.png` and confirm:
- Deep indigo background fills the full square
- Single arc, thick rounded stroke, warm off-white colour
- Arc sweeps from lower-left to upper-right
- Good breathing room on all sides — arc not clipped or cramped

- [ ] **Step 5: Build to confirm Xcode accepts the assets**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add icon/inch-icon.svg \
  "inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024.png" \
  "inch/inch/Assets.xcassets/AppIcon.appiconset/icon-1024-watch.png"
git commit -m "feat: redesign app icon — bold arc on deep indigo"
```
