# Changelog

## 0.1.0 — Unreleased

Initial release: a feature-parity Phlex port of the cmdk React command menu.

- Phlex components rendering the cmdk markup contract: `Cmdk::Root`, `Input`,
  `List`, `Item`, `Group`, `Separator`, `Empty`, `Loading`, `Dialog`, `Footer`
- Dependency-free ES module runtime (`Cmdk.javascript_path`): command-score
  fuzzy filtering, score-based item/group sorting, full keyboard navigation
  (arrows, vim bindings, Home/End, group jumps), pointer selection, IME guard,
  `--cmdk-list-height`, native `<dialog>` palette with sensible, overridable
  placement defaults
- Turbo-native: event delegation + MutationObservers; items streamed in via
  Turbo Streams register automatically
- Extensions over the React API: scoped search (`/` picker, scope pills,
  `scope_only:`, `active_scope:`), footer with selection-driven hints
  (`hint:`/`kbd:`), `href:` items, item-aware custom filters
- Light/dark/system theming via `light-dark()`; Vercel, Linear and Raycast
  theme ports; Lookbook preview suite with a theme switcher
- Mobile defaults: top-anchored sheet dialog, iOS zoom guard, touch-aware
  pointer selection, `enterkeyhint`
