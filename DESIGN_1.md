# Design System Strategy: The Kinetic Minimalist

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Elite Curator."** This system moves beyond the utility of a standard sports app to create a digital environment that feels like a private members' club. It leverages the precision of Apple’s HIG but injects a "New Age" energy through aggressive whitespace, editorial-scale typography, and a "gravity-based" depth model.

The goal is to break the "template" look. We achieve this by avoiding rigid, centered grids in favor of intentional asymmetry—placing high-action photography against expansive white voids. By overlapping bold typography with glass-morphic elements, we create a sense of motion and elite athleticism that feels cutting-edge yet professional.

---

## 2. Colors & Tonal Depth
This system rejects the "flat" web. We use a palette that oscillates between the deep authority of Navy and the electric energy of Tennis Green, anchored by a "Pure White" philosophy.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to define sections. Boundaries must be defined solely through background color shifts.
*   *Implementation:* Use `surface-container-low` (#f3f3f8) sections sitting on a `surface` (#f9f9fe) background. The transition is felt, not seen.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked, physical layers—like sheets of frosted glass.
*   **Base Layer:** `surface` (#f9f9fe)
*   **Secondary Content:** `surface-container` (#ededf2)
*   **Elevated Cards:** `surface-container-lowest` (#ffffff) to create a subtle "pop" against the off-white base.

### The "Glass & Gradient" Rule
To elevate the "New Age" aesthetic:
*   **Glassmorphism:** Use `primary_container` (#001f3f) at 80% opacity with a 20px backdrop blur for floating navigation bars.
*   **Signature Gradients:** For primary CTAs, use a linear gradient from `primary` (#000613) to `primary_container` (#001f3f) at a 135° angle. This adds "soul" and a metallic, premium sheen that flat navy cannot provide.

---

## 3. Typography
We use **Inter** (as the SF Pro equivalent) to drive an editorial narrative. The hierarchy is designed to be "Top-Heavy," emphasizing elite status through scale.

*   **Display (Large/Medium):** Used for scorelines and hero headlines. Set with `extra-bold` weight and `-0.02em` tracking. These should often bleed off the margin or overlap imagery.
*   **Headlines:** High-contrast `bold` weights. Use spacious leading (1.4x to 1.5x) to ensure the text "breathes" like a high-end fashion magazine.
*   **Title & Body:** Clean, functional, and highly legible. `body-lg` (1rem) is the workhorse for player bios and match details.
*   **Labels:** Always uppercase with `+0.05em` letter spacing to denote a technical, "performance-tracking" feel.

---

## 4. Elevation & Depth
Depth is the primary communicator of hierarchy. We do not use structural lines; we use **Tonal Layering.**

### The Layering Principle
Create lift by stacking: Place a `surface-container-lowest` (#ffffff) card on top of a `surface-container-high` (#e8e8ed) background. The contrast in "cleanliness" creates a natural hierarchy.

### Ambient Shadows
When an element must float (e.g., a "Book Court" button):
*   **Blur:** 32px to 48px.
*   **Opacity:** 4% to 8%.
*   **Color:** Use a tinted shadow based on `primary_fixed_dim` (#afc8f0) rather than pure black. This mimics natural light reflecting off a court surface.

### Glassmorphism & Depth
For persistent elements like the Bottom Navigation or Profile Overlays, use semi-transparent surface colors with a `backdrop-filter: blur(20px)`. This allows the vibrant greens of the court photography to bleed through the UI, softening the experience.

---

## 5. Components

### Buttons
*   **Primary:** High-gloss Navy (`primary`) with white text. 24px radius (`xl`).
*   **Accent:** `tertiary_fixed` (#d2f000) for "Live" or "Active" states. This Tennis Green/Yellow is high-visibility and signals peak performance.
*   **Tertiary:** Ghost buttons with no background—only `primary` text.

### Cards & Lists
*   **Rule:** Forbid divider lines.
*   **Style:** Use the Spacing Scale (typically `8` or `10`) to create "Content Islands." Use background shifts (`surface-container-lowest`) to define the card area.
*   **Corner Radii:** Cards must use `md` (1.5rem) or `lg` (2rem) for a friendly yet sophisticated feel.

### Input Fields
*   **Style:** Minimalist. No bottom line or box. Use a `surface-container-highest` (#e2e2e7) background with a `md` (1.5rem) radius.
*   **Active State:** Transition the background to `surface-container-lowest` and add a "Ghost Border" using `outline-variant` at 20% opacity.

### Featured Components (App Specific)
*   **Scoreboard Widget:** A glass-morphic container that floats over live-action photography, using `display-sm` for numbers to emphasize the "Elite" nature of the match.
*   **The Performance Pulse:** A subtle, animated gradient line using `tertiary_fixed` that underlines the active player’s stats, bringing "Kinetic" energy to static data.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical padding. Allow more whitespace on the left or right to create a "New Age" editorial rhythm.
*   **Do** use high-speed, motion-blurred photography of athletes. The UI is the frame; the sport is the focus.
*   **Do** nest containers (Lowest on top of Low) to create depth without shadows.

### Don't
*   **Don't** ever use a 1px #000000 or #CCCCCC border. It breaks the premium "glass and air" illusion.
*   **Don't** crowd the screen. If a screen feels full, increase the spacing scale and move content to a horizontal scroll.
*   **Don't** use standard "drop shadows." If a shadow looks "dirty" or "grey," it is too opaque.