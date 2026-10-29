# Changelog

## 0.2.0 — 2026-10-29

Backward compatible: every 0.1.x option, export, event, markup attribute and
default keeps working; the new behaviour is opt-in or invisible to existing
menus.

- feat: match highlighting, opt-in with the new `Cmdk::ItemLabel` component —
  matched characters are wrapped in `<mark cmdk-match>` while searching and
  the plain text is restored when the search clears (built from text nodes,
  never `innerHTML`); new export `commandScoreWithMatches(value, query,
  keywords)` returns `{ score, matches }` with the same score as
  `commandScore`
- feat: CSP support — the markup has no inline `style` attributes any more
  (the accessible label and `Cmdk::Empty` use the `hidden` attribute); the
  injected base styles take the nonce from `<meta name="csp-nonce">`, can be
  turned off with `<meta name="cmdk-base-styles" content="off">` or put into a
  cascade layer (`content="layer"` / `"layer:<name>"`), and ship as a static
  stylesheet (`Cmdk.base_stylesheet_path`, `assets/css/cmdk_base.css`)
- feat: `destroy(target)` export tears a menu down (observers disconnected,
  state forgotten; a later scan re-initialises it); the Stimulus base
  controller calls it when its menu leaves the page
- feat: `cmdk-item-select` detail also carries `metaKey`, `ctrlKey`,
  `shiftKey` and `altKey`, for alternate actions such as ⌘/Ctrl+Enter
- feat: `Cmdk::Group(heading_attributes:, items_attributes:)` and
  `Cmdk::Root(label_attributes:)` pass extra attributes (class, data-*, …) to
  the heading, the items wrapper and the label
- feat: `Cmdk::Root(native_home_end: true)` lets Home/End move the caret in
  the input instead of selecting the first/last item
- fix: the dialog hotkey also matches the physical key (`event.code`) on
  non-Latin keyboard layouts, where ⌘K reports e.g. `л`
- fix: open cmdk dialogs are closed on `turbo:before-cache`, so a page
  restored from Turbo's cache no longer shows a stale, non-modal palette
- perf: filtering is 2–3× faster per keystroke (median in headless Chrome:
  1,000 items 6.6 → 3.0 ms, 5,000 items 36 → 13 ms) — nodes already in place
  are no longer moved, unchanged attributes and styles are not rewritten, and
  scoring reuses its buffers and caches normalised strings; the resulting DOM
  is identical
- themes: keep `[cmdk-empty][hidden]` hidden and style highlight marks
- tests: Node tests for the scoring functions (`rake test:js`, checked
  against the 0.1.1 implementation), headless-Chrome tests for the runtime
  (`rake test:browser`, Ferrum as a development dependency) and a benchmark
  (`rake bench`); the site gains a Changelog page

Note for custom themes: if your CSS sets `display` on `[cmdk-empty]`, add
`[cmdk-empty][hidden] { display: none }` so the empty state stays hidden
before the runtime starts (once it runs, it controls the display as before).
Passing `style: 'display:none'` to `Cmdk::Empty` restores the 0.1 markup.
If you copied `cmdk.js` into your app instead of serving it from the gem,
update the copy together with the gem: a 0.1 runtime does not remove the
`hidden` attribute that 0.2 renders on `Cmdk::Empty`.

## 0.1.1 — 2026-06-15

- docs: correct the Stimulus base controller import (the bare `cmdk`
  specifier, not `./cmdk.js`); document `dialog_attributes:` and the
  `cmdk-dialog-frame` theme class
- internal: idiomatic Phlex content-block forwarding; deterministic group
  heading ids (monotonic, replacing a random suffix). No markup or API changes.

## 0.1.0 — 2026-06-15

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
