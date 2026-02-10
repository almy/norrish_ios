# Norrish — Brand Identity System

## Creative Direction: Nordic Minimalism

**Prepared by:** UX & Brand Creative Lead
**For:** UX Design Team — Logo & Visual Identity Execution
**Version:** 1.0

---

## 1. Brand Essence

### What Norrish Is

Norrish is a nutrition intelligence companion. It sees what you eat — through your camera lens — and quietly translates it into clarity. It scans barcodes, photographs plates, and returns honest, personalized insight. No noise. No guilt. Just knowledge, delivered with restraint.

### Brand Positioning Statement

> For health-conscious individuals who want to understand what they eat without being overwhelmed, **Norrish** is the nutrition intelligence app that transforms everyday meals into clear, actionable insight — designed with the calm precision of Scandinavian craft.

### Brand Personality

| Trait | Expression |
|---|---|
| **Calm** | The interface breathes. Whitespace is generous. Nothing competes for attention. |
| **Honest** | Data is presented without spin. A Nutri-Score E is shown with the same clarity as an A. |
| **Intelligent** | The technology is sophisticated; the presentation is simple. |
| **Warm** | Nordic minimalism is not cold — it is considered. Rounded corners, natural tones, gentle transitions. |
| **Trustworthy** | Privacy-first, local processing, no dark patterns. The brand earns trust through transparency. |

### Brand Voice

- Speak in short, clear sentences.
- Use active language: "You ate more fiber this week" not "An increase in fiber consumption was detected."
- Never moralize about food choices.
- Use warmth without enthusiasm. Calm confidence, not excitement.

---

## 2. The Name: Norrish

The name draws from **"nourish"** — to sustain, to feed, to care for — filtered through a Nordic lens. The double-r and the "-ish" suffix give it a Scandinavian cadence (cf. *norrland*, *norsk*). It feels like a word that already exists in a language you half-remember.

**Pronunciation:** NOR-ish (rhymes with "flourish")

**Do not** stylize as NORRISH, norrish, or NoRRish. Always: **Norrish**.

---

## 3. Logo Design Brief

### 3.1 Design Philosophy

The logo must embody **restraint as a design decision, not a limitation**. Nordic minimalism treats every element as deliberate. If a stroke can be removed without losing meaning, remove it. If a shape can be simplified further, simplify it.

Reference movements:
- Scandinavian functionalism (Alvar Aalto, Arne Jacobsen)
- Japanese *ma* (negative space as content)
- Swiss typographic tradition (grid, proportion, discipline)

### 3.2 Logo Concept Directions

The UX team should explore **three directions** and present them for review. Each direction must include a primary mark, a wordmark, and a compact/app-icon variant.

---

#### Direction A — "The Lens"

**Concept:** A single, geometric circle — representing both a camera lens and a plate — with a subtle break or aperture that suggests scanning/analysis in progress. The circle is not closed; it has a deliberate gap, implying that Norrish is always looking, always learning.

**Construction notes:**
- Base geometry: circle with a 5–8% arc gap at the 2 o'clock position
- Stroke weight: consistent, medium (not hairline, not heavy)
- The gap may contain a small leaf form or a single-pixel dot to anchor it
- Monochrome execution must work at 16x16px

**Feeling:** Quiet observation. A lens that doesn't intrude.

---

#### Direction B — "The Leaf & Letter"

**Concept:** The lowercase letter **"n"** is drawn with a single continuous stroke where the right vertical stem transitions into an upward leaf form. The leaf is not decorative — it is structural. It replaces the terminal of the letter. This connects language (norrish) to nature (nourishment) in a single gesture.

**Construction notes:**
- Start from a geometric sans-serif "n" (monolinear stroke)
- The right stem curves outward at the top into a tapered leaf shape
- The leaf angle: approximately 30–40 degrees from vertical
- The transition must be smooth — no visible joint between letter and leaf
- Total proportions should fit within a square bounding box for icon use

**Feeling:** Growth from knowledge. Organic intelligence.

---

#### Direction C — "The Score Line"

**Concept:** A horizontal line that subtly undulates — like a gentle waveform or a horizon — representing the act of scanning. Above or below this line sits the wordmark. The line is the brand's constant: it appears in the logo, as a divider in the UI, as the progress indicator during scans. It is both mark and system element.

**Construction notes:**
- The wave should be barely perceptible — almost straight, with a single gentle crest
- Amplitude: no more than 8–10% of line length
- The wave may reference a simplified Nutri-Score gradient when used in color
- In monochrome: a single-weight stroke
- Wordmark sits above the line, left-aligned, with generous space between

**Feeling:** The quiet pulse of data. A heartbeat of understanding.

---

### 3.3 Logo System Requirements

| Variant | Usage | Min Size |
|---|---|---|
| **Primary Mark + Wordmark** | Marketing, website header, splash screen | 120px wide |
| **Primary Mark Only** | App icon, favicon, social avatar | 24px |
| **Wordmark Only** | In-app header, settings screen | 80px wide |
| **Monochrome (dark on light)** | Default usage on light backgrounds | — |
| **Monochrome (light on dark)** | Dark mode, dark backgrounds | — |
| **Single-color mark** | Watermarks, embossing, engraving | 16px |

### 3.4 Clear Space

Minimum clear space around the logo: **1x the height of the "n" in the wordmark** on all sides. No other element may enter this boundary.

### 3.5 What the Logo Must NOT Be

- No gradients in the primary mark (gradients may appear in extended brand, never in the logo itself)
- No drop shadows or 3D effects
- No more than two visual elements (mark + wordmark)
- No literal food illustrations (no forks, no apples, no plates drawn as plates)
- No rounded-rectangle "app icon" shape baked into the logo — that is a container, not the identity
- No trendy effects (glassmorphism, neon glow, etc.)

---

## 4. Color System

### 4.1 Philosophy

Nordic color palettes are drawn from landscape: birch bark, sea fog, lichen, slate, the brief green of a northern summer. Colors in Norrish are **earned** — the default state is neutral. Color enters the interface to convey meaning (Nutri-Score grades, insight categories), not decoration.

### 4.2 Primary Palette

| Token | Name | Hex | Usage |
|---|---|---|---|
| `color.ink` | Ink | `#1A1A1A` | Primary text, logo on light backgrounds |
| `color.paper` | Paper | `#FAFAF8` | Primary background (warm white, not blue-white) |
| `color.stone` | Stone | `#8A8A8A` | Secondary text, captions, metadata |
| `color.mist` | Mist | `#E8E8E4` | Borders, dividers, subtle containers |
| `color.snow` | Snow | `#FFFFFF` | Card surfaces, elevated elements |

### 4.3 Accent — Nordic Green

The single brand accent color. Used sparingly: CTAs, active states, the Norrish mark when color is applied.

| Token | Name | Hex | Usage |
|---|---|---|---|
| `color.accent` | Fjord | `#2E8B6A` | Primary accent — buttons, active tabs, links |
| `color.accent.soft` | Fjord Light | `#E6F5EF` | Accent backgrounds, selected states |
| `color.accent.deep` | Fjord Deep | `#1D6B4F` | Pressed states, dark-mode accent |

**Why this green:** It sits between mint and forest — cooler than the current `Color.mint`, warmer than clinical teal. It references lichen on stone, not traffic lights or health-app cliches.

### 4.4 Semantic / Functional Colors

These are **data colors**, not brand colors. They carry meaning.

| Token | Name | Hex | Context |
|---|---|---|---|
| `nutri.a` | Grade A | `#22C55E` | Nutri-Score A (excellent) |
| `nutri.b` | Grade B | `#84CC16` | Nutri-Score B (good) |
| `nutri.c` | Grade C | `#EAB308` | Nutri-Score C (moderate) |
| `nutri.d` | Grade D | `#F97316` | Nutri-Score D (poor) |
| `nutri.e` | Grade E | `#EF4444` | Nutri-Score E (bad) |
| `insight.health` | Health | `#22C55E` | Health-related insights |
| `insight.habit` | Habit | `#A855F7` | Habit pattern insights |
| `insight.pref` | Preference | `#3B82F6` | Preference-based insights |
| `insight.rec` | Recommendation | `#F97316` | Recommendation insights |

### 4.5 Dark Mode

Dark mode is not an inversion — it is a parallel palette.

| Light Token | Dark Equivalent | Hex |
|---|---|---|
| `color.paper` | `color.night` | `#111111` |
| `color.snow` | `color.charcoal` | `#1C1C1E` |
| `color.ink` | `color.frost` | `#F0F0EC` |
| `color.stone` | `color.ash` | `#9A9A9A` |
| `color.mist` | `color.slate` | `#2C2C2E` |
| `color.accent` | `color.accent` | `#34D399` (slightly lifted for dark contrast) |

---

## 5. Typography

### 5.1 Philosophy

Nordic typography favors **legibility over personality**. The typeface should feel invisible — the reader notices the words, not the font. We pair a humanist sans-serif for UI with an editorial serif for display moments.

### 5.2 Type Scale

#### Primary — UI and Body

**Font:** `SF Pro` (system) or **Inter** (if custom font is approved)

Inter is the recommended custom alternative: designed for screens, open-source, with excellent legibility at small sizes and a subtle warmth that distinguishes it from geometric sans-serifs.

| Role | Weight | Size | Tracking | Line Height |
|---|---|---|---|---|
| Page Title | Bold (700) | 30pt | -0.02em | 1.15 |
| Section Header | Semibold (600) | 20pt | -0.01em | 1.25 |
| Body | Regular (400) | 15pt | 0 | 1.5 |
| Body Emphasis | Medium (500) | 15pt | 0 | 1.5 |
| Caption | Regular (400) | 12pt | 0.04em | 1.4 |
| Overline | Medium (500) | 10pt | 0.08em (uppercase) | 1.5 |
| Data / Numbers | Tabular Figures, Medium | 15pt | 0 | 1.3 |

#### Secondary — Display and Editorial

**Font:** `New York` (system serif) or **Libre Caslon Text** (if custom)

Used for: the wordmark in the logo, insight headlines, onboarding titles, the home screen greeting. Serif text signals a shift from utility to narrative — "here is something worth reading slowly."

| Role | Weight | Size | Tracking |
|---|---|---|---|
| Display Title | Regular (400) | 34pt | -0.02em |
| Insight Headline | Regular (400) | 22pt | -0.01em |
| Wordmark | Regular (400) | Custom | -0.03em |

### 5.3 Typographic Rules

- **Never use more than two font families** on a single screen.
- **Serif is reserved** for display and editorial contexts only — never for buttons, labels, or navigation.
- **Numbers in nutrition data** must use tabular (monospaced) figures to ensure column alignment.
- **Uppercase** is permitted only for overlines (e.g., "NUTRI-SCORE", "THIS WEEK") and must have letter-spacing of at least 0.06em.
- **Line length** for body text should not exceed 65 characters.

---

## 6. Spacing & Layout

### 6.1 Base Unit

**4px base grid.** All spacing values are multiples of 4.

| Token | Value | Usage |
|---|---|---|
| `space.xs` | 4px | Tight internal spacing (icon-to-label) |
| `space.sm` | 8px | Related element spacing |
| `space.md` | 16px | Default content padding |
| `space.lg` | 24px | Section separation |
| `space.xl` | 32px | Major section breaks |
| `space.2xl` | 48px | Screen-level vertical rhythm |

### 6.2 Card System

Cards are the primary content container. They should feel like paper — flat, with presence implied by separation rather than shadow.

| Property | Value |
|---|---|
| Corner radius | 12px |
| Internal padding | 16px |
| Background | `color.snow` (light) / `color.charcoal` (dark) |
| Border | 1px `color.mist` (light) / 1px `color.slate` (dark) |
| Shadow | `0 1px 3px rgba(0,0,0,0.04)` — barely visible, provides lift |
| Card-to-card gap | 12px |

### 6.3 Screen Margins

- Horizontal: 20px (iPhone SE / standard), 24px (Pro Max / large)
- Top safe area respected; content begins 16px below safe area
- Bottom: 32px above tab bar

---

## 7. Iconography

### 7.1 Style

- **Outline icons** as default (1.5px stroke, rounded caps and joins)
- **Filled icons** for active/selected states only (e.g., active tab)
- Consistent 24x24px optical grid
- Corner radius on icon shapes: 2px
- Based on SF Symbols conventions for native feel, or a curated set from Phosphor Icons (which shares the Nordic quality of restrained line work)

### 7.2 Custom Icons Needed

| Icon | Description | Context |
|---|---|---|
| Scan / Barcode | Simplified barcode with scan line | Scan tab, scan button |
| Plate / Bowl | Top-down circle with subtle food suggestion | Plate analysis entry |
| Leaf | Single leaf, matching logo leaf if Direction B | Nutri-Score A, healthy tags |
| Trend Line | Gentle upward curve | Insights, weekly trends |
| Filter | Horizontal lines with adjustment dots | History filter |
| Camera | Minimal camera outline | Capture actions |

---

## 8. Motion & Interaction

### 8.1 Principles

- **Motion should clarify, not decorate.** Every animation answers "where did this come from?" or "where is this going?"
- **Duration:** 200–300ms for micro-interactions, 400–500ms for page transitions
- **Easing:** `easeInOut` for most transitions. `spring(response: 0.4, dampingFraction: 0.8)` for interactive gestures
- **No bounce** except on direct-manipulation gestures (pull-to-refresh, drag-to-dismiss)

### 8.2 Key Animations

| Element | Animation | Duration |
|---|---|---|
| Card appear | Fade in + translate Y 8px | 300ms, staggered 50ms |
| Tab switch | Cross-fade | 200ms |
| Scan line | Continuous vertical sweep | 1.5s loop, ease-in-out |
| Nutri-Score reveal | Scale from 0.8 to 1.0 + fade | 400ms, spring |
| Insight carousel | Horizontal scroll with parallax | Gesture-driven |
| Progress ring | Stroke-end animation | 800ms, ease-out |

---

## 9. Photography & Imagery

### 9.1 Style Direction

When photography is used (onboarding, marketing, empty states):

- **Natural light only.** No studio flash. Overcast or golden-hour preferred.
- **Muted, desaturated tones.** Reduce saturation by 15–20% from capture.
- **Overhead or 3/4 angle** for food. Never eye-level "food blog" style.
- **Simple compositions.** One subject, neutral surface (light wood, linen, stone).
- **No hands holding phones.** No screens-within-screens. Show the food, not the technology.
- **Scandinavian settings:** light wood tables, ceramic plates (not white china), natural textiles.

### 9.2 Illustration

If illustration is needed (error states, onboarding):

- Single-weight line illustration (matching icon stroke weight)
- Monochrome or accent-color-only
- No fills except for the accent green
- Subject matter: simple food forms, abstract plant shapes, geometric kitchen objects
- Reference artists: Lotta Nieminen, Toma Vagner

---

## 10. App Icon Specification

### 10.1 Construction

The app icon lives in a 1024x1024px artboard, displayed at varying sizes from 16x16 to 180x180.

| Property | Value |
|---|---|
| Background | `color.paper` (#FAFAF8) |
| Mark color | `color.ink` (#1A1A1A) or `color.accent` (#2E8B6A) |
| Mark size | 60% of artboard (centered) |
| Padding | 20% on each side |
| Corner radius | Applied by OS (do not bake in) |

### 10.2 Variants to Produce

- 1024x1024 — App Store
- 180x180 — iPhone @3x
- 120x120 — iPhone @2x
- 167x167 — iPad Pro
- 152x152 — iPad
- 76x76 — iPad @1x
- 40x40 — Spotlight
- 29x29 — Settings
- 16x16 — Accessibility test (must remain legible)

---

## 11. Deliverables Checklist

The UX team must deliver the following assets:

- [ ] **Logo exploration** — 3 directions, 3 variations each (9 concepts minimum)
- [ ] **Final logo** — All variants (mark, wordmark, combined) in SVG + PDF
- [ ] **App icon** — All sizes, light and dark variants
- [ ] **Color palette** — Figma library with all tokens, light and dark
- [ ] **Typography specimens** — Figma text styles matching Section 5
- [ ] **Icon set** — Custom icons listed in Section 7, SVG, 24x24 optical grid
- [ ] **Component library** — Cards, buttons, badges, inputs following this guide
- [ ] **Motion specs** — Principle/Figma prototype demonstrating key animations
- [ ] **Photography moodboard** — 12–16 reference images matching Section 9
- [ ] **Brand one-pager** — A single-page PDF summarizing the identity for external partners

---

## 12. References & Moodboard Direction

### Brands to Study

| Brand | What to learn |
|---|---|
| **Oura Ring** | Health data presented with restraint. Dark UI with calm authority. |
| **Aesop** | Typography-led identity. Product speaks; brand whispers. |
| **Kinfolk Magazine** | Editorial warmth. Serif + sans pairing. Photography style. |
| **Muji** | The absence of branding as branding. Functional beauty. |
| **Cereal Magazine** | Whitespace as luxury. Travel/lifestyle through a Nordic lens. |
| **Acne Studios** | Scandinavian identity that is minimal but not generic. |

### Avoid These Patterns

- "Bright and friendly" health-app aesthetics (MyFitnessPal, Noom)
- Gamification or streaks (Duolingo-style engagement)
- Medical/clinical appearance (white + blue + icons of body parts)
- Gradient-heavy modern SaaS branding
- Illustrated mascots or characters

---

## 13. Implementation Notes for Engineering

When the design team delivers final assets, engineering should update:

| File | Change |
|---|---|
| `AppStyles.swift` | Update `AppColors` to match token system in Section 4 |
| `Assets.xcassets/Colors/` | Add color sets for all tokens with light/dark variants |
| `Assets.xcassets/AppIcon` | Replace with final icon set |
| `ThemeManager.swift` | Extend to support the full dark palette |
| `NutritionStyles.swift` | Verify Nutri-Score colors match Section 4.4 |
| `ContentView.swift` | Update tab icons to new custom icon set |
| `Info.plist` | Update display name, bundle name if needed |

---

*This document defines the visual soul of Norrish. Every decision flows from one principle: show only what matters, and show it beautifully. Nordic minimalism is not about removing things — it is about knowing what deserves to stay.*
