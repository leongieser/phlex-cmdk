# ⌘K for Phlex <img src="https://img.shields.io/badge/port%20of-cmdk-blue" align="right">

A feature-parity port of the [cmdk](https://cmdk.paco.me) React command menu, built for
[Phlex](https://www.phlex.fun). Two pieces, and that is the whole dependency surface:

- **Phlex components** (`Cmdk::Root`, `Input`, `List`, `Item`, `Group`, `Separator`, `Empty`,
  `Loading`, `Dialog`, `Footer`) render the exact same markup contract as the React package - the
  `cmdk-*` attributes and ARIA roles. Existing cmdk themes work unchanged.
- **One dependency-free ES module** ([assets/js/cmdk.js](assets/js/cmdk.js)) ports
  `command-score` verbatim and reimplements the cmdk component's behavior in vanilla JS: fuzzy filtering, score-based sorting of items and
  groups, keyboard navigation (arrows, `ctrl+n/j/p/k` vim bindings, Home/End, `alt` = group
  jump, `meta` = first/last), pointer selection, empty state, IME composition guard,
  `--cmdk-list-height`, and a native `<dialog>` command palette.

The only runtime dependency is `phlex`. Everything past that is your choice:

- **Styling** - the components ship no styles of their own, only the `cmdk-*` attribute
  contract. Bring plain CSS, SCSS or Tailwind, or drop in one of the [ready-made themes](#styling).
- **Behavior** - every interaction is a bubbling DOM event. Wire it with a plain
  `addEventListener`, the [optional Stimulus base controller](#with-stimulus), or any framework.
- **Navigation** - `href:` items use Turbo's `visit` when [Turbo](https://turbo.hotwired.dev)
  is on the page and fall back to a normal navigation when it is not. Nothing to configure either way.

The runtime uses event delegation and MutationObservers rather than mounting, so it survives
Turbo navigation and morphing with no per-page setup, and items appended later (Turbo Streams,
your own DOM writes) are registered, filtered and sorted automatically.

## Install

```ruby
# Gemfile
gem 'phlex-cmdk'
```

Serve or bundle the runtime once per page. Its path is exposed as `Cmdk.javascript_path`
(copy it into your assets, pin it in your importmap, or serve it directly):

```html
<script type="module" src="/cmdk.js"></script> <!-- auto-starts on import -->
```

The components are unstyled; optionally start from the shipped themes
(`Cmdk.stylesheet_path` - see [Styling](#styling)).

### With Rails (importmap + Propshaft)

Serve the gem assets straight from the gem - no copying:

```ruby
# config/initializers/cmdk.rb
Rails.application.config.assets.paths << File.dirname(Cmdk.javascript_path)
Rails.application.config.assets.paths << File.dirname(Cmdk.stylesheet_path)
```

```ruby
# config/importmap.rb
pin "cmdk", to: "cmdk.js"
pin "cmdk_controller", to: "cmdk_controller.js" # optional Stimulus base controller
```

```js
// app/javascript/application.js
import "cmdk"
```

```erb
<%# layout - optional ready-made themes %>
<%= stylesheet_link_tag "cmdk_themes", "data-turbo-track": "reload" %>
```

### With Tailwind

Everything composes with a Tailwind v4 setup out of the box: components accept
`class:` attributes like any Phlex element, the runtime needs no build step, and
the shipped themes are plain CSS you can import into your input stylesheet:

```css
@import 'tailwindcss';
@import '../path/to/cmdk_themes.css'; /* copied from Cmdk.stylesheet_path */
```

```ruby
Cmdk::Root(class: 'cmdk-vercel w-full max-w-xl') do ... end
```

No `@source` configuration is needed for the gem - its components emit no
Tailwind utilities of their own.

**Do I need tailwind-merge / cn()?** No, by design. That pattern exists because
React component libraries ship utility-class defaults which consumers override
in the same class attribute; which one wins depends on stylesheet order, so
tailwind-merge rewrites the string. cmdk-phlex components emit no utility
classes at all - your `class:` passes through untouched, so there is nothing to
conflict with. The shipped themes live in `@layer components` while Tailwind's
utilities layer comes later, so a utility on a component
(`Cmdk::Item(class: 'pt-3')`) overrides the theme without any merging - and
without Tailwind, your own unlayered CSS overrides the layered themes just the
same. If you build your own variant components with conditional utility
defaults on top, that is regular Phlex + Tailwind territory: reach for the
[tailwind_merge](https://github.com/gjtorikian/tailwind_merge) gem exactly
where you would reach for cn(). (Heads-up: Tailwind's preflight resets break
native `<dialog>` centering; the runtime ships zero-specificity defaults that
handle this - see [Dialog](#dialog).)

## Use

```ruby
class CommandMenu < Phlex::HTML
  def view_template
    Cmdk::Root(label: 'Global Command Menu', loop: true) do
      Cmdk::Input(placeholder: 'What do you need?')
      Cmdk::List() do
        Cmdk::Empty() { 'No results found.' }

        Cmdk::Group(heading: 'Suggestions') do
          Cmdk::Item(value: 'linear', keywords: %w[issue tracker]) { 'Linear' }
          Cmdk::Item(value: 'figma', disabled: true) { 'Figma' }
        end

        Cmdk::Separator()
        Cmdk::Item(href: '/settings') { 'Settings' } # Turbo.visit on select
      end
    end
  end
end
```

Every interaction is a bubbling DOM event, so listen on the root, the document, or via a
Stimulus action (`data-action="cmdk-item-select->palette#run"`):

```js
root.addEventListener('cmdk-item-select', (e) => run(e.detail.value)) // cancelable
root.addEventListener('cmdk-value-change', (e) => preview(e.detail.value))
root.addEventListener('cmdk-search-change', (e) => e.detail.search)
```

### Dialog

```ruby
Cmdk::Dialog(label: 'Command Menu', hotkey: 'k') do  # ⌘K / ctrl+K toggles it
  Cmdk::Input()
  Cmdk::List() { ... }
end
```

Renders a native `<dialog cmdk-dialog>`: Escape and backdrop clicks close it, and
`Cmdk.openDialog(el)` / `Cmdk.closeDialog(el)` toggle it programmatically. Style the
backdrop with `dialog[cmdk-dialog]::backdrop` (replaces Radix's `[cmdk-overlay]`).

By default the dialog renders as a top-third, horizontally centered palette; on
viewports ≤640px it becomes a top-anchored, full-width sheet (the GitHub/Jira
pattern - the software keyboard owns the bottom of the screen, so the input
belongs at the top), sized with `dvh` units so dynamic viewports behave. CSS
resets (e.g. Tailwind preflight's universal `margin: 0`) break native `<dialog>`
centering, so the runtime injects these defaults with zero specificity (`:where()`)
- any rule of yours wins, even a bare element selector:

```css
dialog[cmdk-dialog] { margin-top: 30vh; }   /* overrides the default placement */
```

Other mobile defaults: the shipped themes bump the input to 16px under 640px
(prevents iOS Safari's focus zoom), `Cmdk::Input` sets `enterkeyhint="go"` for
the mobile keyboard, and touch-move over items doesn't drag the selection
around while scrolling (only real pointer hover selects).

### Scoped search

cmdk deliberately keeps its filter vanilla; modes like `fruit: <query>` are userland.
This port gives you both levels:

**Declarative scopes** - declare them on the root, tag items or groups, and offer
scope-entry items for the picker:

```ruby
Cmdk::Root(label: 'Search', scopes: %w[fruits doc]) do
  div(class: 'cmdk-search-row') { Cmdk::Input() }     # flex row hosts the pill
  Cmdk::List() do
    Cmdk::Item(enters_scope: 'fruits') { 'Search fruits…' }
    Cmdk::Group(heading: 'Fruits', scope: 'fruits', scope_only: true) { ... }
    Cmdk::Group(heading: 'Docs',   scope: 'doc') { ... }
  end
end
```

The flow follows the Linear/Slack/Raycast pattern (and cmdk's own "pages" recipe):

- Typing `/` suggests the `enters_scope:` items; `/f` narrows them.
- Enter (or click) pins the scope as a **pill** (`[cmdk-scope-pill]`, a button
  inserted before the input) and clears the input - typing then filters only
  items/groups tagged with that `scope:`. The pill carries
  `data-scope="fruits"`, so you can style each scope distinctly
  (`[cmdk-scope-pill][data-scope="fruits"]`) and fall back to the bare
  `[cmdk-scope-pill]` rule.
- Typing the name out (`/fruits `) commits too.
- Backspace on an empty input or clicking the pill leaves the scope.

The root mirrors the state as `data-cmdk-active-scope="fruits"`, and events carry the
parsed parts - ideal for a server-backed lookup in a Turbo app, since streamed-in
items register automatically:

```js
root.addEventListener('cmdk-scope-change', (e) => {
  if (e.detail.scope === 'fruits') frame.src = `/search/fruits?q=${e.detail.query}`
})
```

The picker prefix is configurable (`scope_picker: ':'`) or can be turned off
(`scope_picker: false`). Server-render an already-pinned scope with
`Cmdk::Root(active_scope: 'fruits')`. Programmatic: `Cmdk.enterScope(root, 'fruits')` /
`Cmdk.exitScope(root)`.

By default scoped items also match global (unscoped) searches. Mark a group or item
with `scope_only: true` to require deliberate entry - it stays hidden (and excluded
from the result count) unless its scope is active:

```ruby
Cmdk::Group(heading: 'Fruits', scope: 'fruits', scope_only: true) { ... }
```

**Server-backed scopes** - for data that lives in your database (fruits, documents),
mark the scoped group `server_filtered: true` and put a turbo-frame inside it. The
runtime then shows the streamed-in items as-is instead of fuzzy-matching them against
the query - which means the query can be a *server-side grammar*, e.g. `color:red
sweet`:

```ruby
Cmdk::Group(heading: 'Fruits', scope: 'fruits', scope_only: true, server_filtered: true) do
  turbo_frame(id: 'fruit-results')
end
```

```js
searchChanged({ detail: { scope, query } }) {       // Stimulus base controller hook
  if (scope === 'fruits') frame.src = `/search/fruits?q=${encodeURIComponent(query)}`
}
```

The endpoint parses the predicates, queries the database and renders `Cmdk::Item`s
into the frame; selection, keyboard navigation, footer hints and the empty state all
work on the streamed items automatically.

**Fully custom syntax** - the filter function receives the item element as a 4th
argument (an extension over the React signature), so any operator grammar is possible:

```js
Cmdk.setFilter(root, (value, query, keywords, item) => {
  // parse your own syntax here; return 0 to hide, 0..1 to rank
  return Cmdk.defaultFilter(value, query, keywords)
})
```

### Footer with selection hints

Raycast-style palettes show a footer hinting at what Enter will do for the
*selected* item. Declare hints on items and drop a `Cmdk::Footer` after the list:

```ruby
Cmdk::Item(hint: 'Open in New Tab', kbd: '⌘ ↵') { 'Figma' }

Cmdk::Footer() do            # or no block for just the hint container
  span { '🚀' }
  div('cmdk-footer-hint' => '')
end
```

The runtime fills `[cmdk-footer-hint]` as the selection moves - the hint text in a
`<span>`, each key of `kbd:` as its own `<kbd>` cap - and sets `data-empty` when the
selected item declares no hint. For anything richer, drive your own footer from the
`cmdk-value-change` event.

### With Stimulus

The bubbling events work with plain action descriptors - no controller required:

```html
<div data-controller="palette"
     data-action="cmdk-item-select->palette#run cmdk-scope-change->palette#search">
```

For more structure, the gem ships an optional base controller
(`Cmdk.stimulus_controller_path`; serve it next to the runtime, it imports
the runtime as the bare specifier `cmdk` and `@hotwired/stimulus`). Extend it
and override the hooks:

```js
import CmdkController from 'cmdk_controller' // pin to Cmdk.stimulus_controller_path

export default class extends CmdkController {
  itemSelected({ detail: { value } }) { this.run(value) }
  scopeChanged({ detail: { scope, query } }) { /* server-backed lookup */ }
}
```

Hooks: `itemSelected`, `valueChanged`, `searchChanged`, `scopeChanged`. API and
actions: `open`/`close`/`toggle` (dialog), `setSearch`, `setValue`, `enterScope`
(param-friendly: `data-action="cmdk#enterScope" data-cmdk-scope-param="fruits"`),
`exitScope`, and a `state` getter.

### Styling

Unstyled by design: the components ship no styles, only the `cmdk-*` attribute
contract. With Tailwind, the idiomatic way is utilities on the components
themselves - the runtime toggles `data-*` attributes,
so Tailwind's data variants cover the states:

```ruby
Cmdk::Item(class: 'flex h-10 items-center rounded-lg px-3
                   data-[selected=true]:bg-neutral-100
                   data-[disabled=true]:text-neutral-300') { 'Apple' }
```

Or target the attribute contract from a stylesheet (plain CSS, no build needed):

```css
[cmdk-item][data-selected='true'] { background: #f5f5f5; }
[cmdk-group-heading] { padding: 8px 12px 6px; font-size: 12px; color: #a3a3a3; }
[cmdk-list] { height: min(330px, var(--cmdk-list-height)); transition: height 100ms ease; }
```

The gem also ships a default theme as plain, dependency-free CSS
([assets/css/cmdk_themes.css](assets/css/cmdk_themes.css), path via
`Cmdk.stylesheet_path`). Opt in with `class: 'cmdk'` on the root - it only
styles menus you ask it to, never the ones you style yourself. The look is
driven by CSS variables, so you re-theme by overriding a handful of tokens
instead of rewriting selectors:

```css
/* The defaults (override any of these to re-theme): */
:root {
  --cmdk-radius: 12px;   --cmdk-item-radius: 8px;   --cmdk-pill-radius: 6px;
  --cmdk-bg:        light-dark(#ffffff, #18181b);
  --cmdk-fg:        light-dark(#171717, #ededef);
  --cmdk-muted:     light-dark(#a3a3a3, #71717a);   /* headings, footer, placeholder */
  --cmdk-border:    light-dark(#e5e5e5, #27272a);
  --cmdk-accent:    light-dark(#f5f5f5, #27272a);   /* selected row */
  --cmdk-accent-fg: light-dark(#0a0a0a, #fafafa);
  --cmdk-pill:      light-dark(#e5e5e5, #3f3f46);
  --cmdk-pill-fg:   light-dark(#404040, #d4d4d8);
}

/* Re-theme globally or on a wrapper by overriding tokens: */
:root { --cmdk-accent: #ffe08a; --cmdk-radius: 6px; }
```

Two ready-made looks ship as token presets: `class: 'cmdk-linear'` or
`'cmdk-raycast'` (`'cmdk-vercel'` is an alias for the default). All are
browsable in Lookbook under "Themes". The
[styling page](https://leongieser.github.io/phlex-cmdk/styling.html) has a live
token builder that emits these overrides as CSS or Tailwind.

**Dark mode** - the shipped themes declare every color with `light-dark()` and resolve
through `color-scheme`, giving the standard tri-state:

```css
:root { color-scheme: light dark; }              /* "system": the OS decides */
:root[data-theme='light'] { color-scheme: light; }
:root[data-theme='dark']  { color-scheme: dark; }
```

Leave `data-theme` off (or `system`) to follow the OS preference; set
`<html data-theme="dark">` to force a side - no duplicated selectors, one declaration
per color. The Lookbook previews expose this as a Theme dropdown in the preview toolbar.

## React → Phlex parity map

| React | Here |
|---|---|
| `<Command label shouldFilter loop vimBindings disablePointerSelection defaultValue>` | `Cmdk::Root(label:, should_filter:, loop:, vim_bindings:, disable_pointer_selection:, default_value:)` |
| `<Command value onValueChange>` (controlled) | `Cmdk.setValue(root, v)` + `cmdk-value-change` event |
| `filter={fn}` | `Cmdk.setFilter(fn)` or `Cmdk.setFilter(root, fn)` - same `(value, search, keywords) → 0..1` signature |
| `<Command.Input value onValueChange>` | `Cmdk::Input(value:)`; `Cmdk.setSearch(root, q)`; `cmdk-search-change` |
| `<Command.List label>` | `Cmdk::List(label:)` |
| `<Command.Item value keywords disabled forceMount onSelect>` | `Cmdk::Item(value:, keywords:, disabled:, force_mount:)`; `cmdk-item-select` event; value inferred from text content when omitted |
| `<Command.Group heading value forceMount>` | `Cmdk::Group(heading:, value:, force_mount:)` |
| `<Command.Separator alwaysRender>` | `Cmdk::Separator(always_render:)` |
| `<Command.Empty>` / `<Command.Loading progress label>` | `Cmdk::Empty()` / `Cmdk::Loading(progress:, label:)` |
| `<Command.Dialog open onOpenChange container>` | `Cmdk::Dialog(open:, hotkey:)` - native `<dialog>`, no portal needed |
| `useCommandState(selector)` | `Cmdk.getState(root)` + the events above |
| vim bindings, Home/End, alt/meta arrows, IME guard | identical, ported from the same keydown logic |

Extensions beyond the React API: `Cmdk::Item(href:)` visits a URL on select (via Turbo when
present), and clearing the search restores the server-rendered order (React leaves the
sorted order in place).

## Demo, previews & tests

```sh
bundle install
bundle exec rake test      # component markup contract tests
bundle exec rake demo      # builds Tailwind CSS, serves http://localhost:9292
bundle exec rake lookbook  # Lookbook component previews on http://localhost:9293
```

The [Lookbook](https://lookbook.build) previews live in [lookbook/](lookbook/) - Lookbook is a
Rails engine, so a minimal single-file Rails host ([lookbook/app.rb](lookbook/app.rb)) boots it;
the gem itself stays Rails-free. Scenarios cover the default menu (with live params for
placeholder/loop/vim bindings), ungrouped items, `should_filter: false`, force-mounted
items, loading, the empty state, the event log, and the ⌘K dialog.
