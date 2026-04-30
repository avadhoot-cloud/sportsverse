# Design System Blueprint: Elite Curator (Grand Slam Edition)

## 1. System Extraction & Foundation
The "Elite Curator" system is built on **Kinetic Minimalism**. It uses high-contrast typography and intentional whitespace to create a sense of prestige and authority.

### Color System
- **Primary:** Deep Navy (#001F3F) — Core branding, primary text, high-priority buttons.
- **Surface:** Pure White (#FFFFFF) — The primary canvas.
- **Accent:** High-Visibility Lime (#D2F000) — Exclusively for "Live" states, active indicators, and high-energy CTAs.
- **Neutral:** Cool Grey (#EDEDF2) — Subtle borders, secondary backgrounds, and dividers.
- **States:**
    - Success: #D2F000 (Lime)
    - Warning: Soft Amber (used sparingly)
    - Inactive: #94A3B8 (Slate 400)

### Typography Scale (Inter)
- **Display 1:** 32px+, Black (900), -0.04em tracking.
- **Display 2:** 24px, ExtraBold (800), -0.02em tracking.
- **Headline:** 18px, Bold (700), -0.01em tracking.
- **Subhead:** 14px, Semibold (600), Uppercase + Letter Spacing (0.05em).
- **Body:** 16px, Regular (400), 1.6 line-height.
- **Caption:** 12px, Medium (500), Uppercase.

### Spacing & Elevation
- **Grid:** 8px base unit.
- **Section Padding:** 24px (Mobile), 48px+ (Desktop).
- **Card Spacing:** 16px - 24px.
- **Shadows:** Minimal. Use `shadow-sm` or 1px borders (#EDEDF2) to define depth.

---

## 2. Component System

### Buttons
- **Primary:** Full-width (Mobile), Rounded-Full, Navy (#001F3F) background, White text.
- **Secondary:** White background, 1px Navy border, Navy text.
- **Accent (Live):** Lime (#D2F000) background, Navy text.

### Data Tables & Lists
- **Layout:** Vertical, expanded card-based approach for Mobile.
- **Headers:** All caps, Bold, Navy, 12px.
- **Rows:** Ample vertical padding (20px+). No vertical dividers.
- **Indicators:** Winner/Active states indicated by a sharp Navy tick mark or a Lime dot.

### Cards
- **Radius:** 32px (Large).
- **Padding:** 24px internal.
- **Style:** Pure white with subtle #EDEDF2 border or very soft shadow.

---

## 3. Interaction & Motion
- **Easing:** `cubic-bezier(0.4, 0, 0.2, 1)` for that snappy iOS feel.
- **Hover:** Subtle opacity shift (0.8) or slight scale-up (1.02).
- **Transitions:** Fast (200ms - 300ms) page fades and slide-ups.

---

## 4. Sports Academy Adaptation
- **Player Dashboards:** Use image-led cards for performance tracking. High-contrast "Top 10%" or "Leader" badges in Navy pills.
- **Schedules:** Use a vertical "Time-line" logic with clear "Join" or "Check-in" CTAs.
- **Fee Management:** High-clarity cards showing "Paid" vs "Outstanding" with bold typography for amounts.

---

## 5. Master Transformation Prompt for Antigravity
> **Role:** Senior UI/UX Designer specialized in Premium iOS Sports Interfaces.
> **Objective:** Transform a basic management UI into the "Elite Curator" premium system.
> **Visual Rules:**
> 1. Set background to Pure White (#FFFFFF).
> 2. Use **Inter** font. Headings must be **ExtraBold (800)** in Deep Navy (#001F3F) with -0.04em tracking.
> 3. Apply **32px border-radius** to all cards and containers.
> 4. Use #EDEDF2 for 1px borders or subtle separators.
> 5. **Buttons:** Primary must be #001F3F with White text, fully rounded.
> 6. **Accents:** Use #D2F000 (Lime) only for "LIVE" status or critical primary actions.
> 7. **Layout:** Prioritize massive whitespace. Remove all vertical grid lines from tables.
> 8. **Atmosphere:** The UI must feel like a high-end lifestyle magazine—clean, breathable, and authoritative.

---

## 6. Golden Rules (Non-Negotiable)
- **Typography is UI:** Let font weight and size define hierarchy, not boxes and lines.
- **Intentional Whitespace:** If it feels crowded, double the padding.
- **High-Contrast Only:** No light grey on white. Ensure all text is authoritative Navy.
- **iOS Native Polish:** Follow SF Symbols stroke weights and Apple's spacing rhythms.