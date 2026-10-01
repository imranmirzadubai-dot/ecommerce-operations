# UI-004 — Design Tokens

**Master Plan:** UI-MP-1.2  
**Branch:** `ui/ui-mp-1.2-baseline-contract-audit`  
**Protected restore gate:** `UI-RESTORE-GATE-2026-10-01`

## Purpose

Establish the presentation-only token layer for the locked visual direction:

- **A — Clean Modern SaaS** as the global foundation.
- **B — Modern Operations** as the primary operational language.
- **C — Modern Logistics Command Center** only selectively on scan/field operational surfaces.

## Token groups

- neutral palette and semantic surfaces
- accent/focus colour
- success, warning, danger and informational status colours
- typography scale
- spacing scale
- border radii
- restrained elevation
- control/touch-target sizing
- responsive breakpoints
- motion timing and reduced-motion handling

## Implementation

- `src/styles/design-tokens.css` contains the global token definitions.
- `src/index.css` imports the token layer and applies the global focus-visible treatment.
- Existing application CSS continues to consume the existing semantic variables (`--app-bg`, `--surface`, `--text`, `--text-h`, `--muted`, `--border`), now sourced from the token system.
- No command, API, authentication, authorization, database, state-machine or business workflow code is changed.

## Design constraints

1. Keep the application primarily light; do not introduce a blanket dark theme.
2. Avoid heavy gradients and decorative effects.
3. Use shadows sparingly.
4. Maintain practical touch targets, with 44px as the minimum token target.
5. Respect `prefers-reduced-motion`.
6. Tokens describe presentation only; business states remain owned by existing application contracts.
7. Screen implementation and responsive mockups remain separate from token creation.

## UI-004 acceptance

UI-004 is complete when the token layer is committed, globally imported, and build/type checks pass without changing protected application contracts.
