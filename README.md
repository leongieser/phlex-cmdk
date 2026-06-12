# ⌘K for Phlex <img src="https://img.shields.io/badge/port%20of-cmdk-blue" align="right">

A feature-parity port of the [cmdk](https://cmdk.paco.me) React command menu for Ruby projects
using [Phlex](https://www.phlex.fun), [Turbo](https://turbo.hotwired.dev) and Tailwind.

Two pieces:

- **Phlex components** (`Cmdk::Root`, `Input`, `List`, `Item`, `Group`, `Separator`, `Empty`,
  `Loading`, `Dialog`) render the exact same markup contract as the React package — the
  `cmdk-*` attributes and ARIA roles. Existing cmdk themes work unchanged.
- **One dependency-free ES module** ([assets/js/cmdk.js](assets/js/cmdk.js)) ports
  `command-score` and the React runtime: fuzzy filtering, score-based sorting of items and
  groups, keyboard navigation (arrows, `ctrl+n/j/p/k` vim bindings, Home/End, `alt` = group
  jump, `meta` = first/last), pointer selection, empty state, IME composition guard,
  `--cmdk-list-height`, and a native `<dialog>` command palette.

No Stimulus required (it composes fine with it). The runtime uses event delegation and
MutationObservers, so it survives Turbo navigation and morphing, and items appended via
Turbo Streams are registered, filtered and sorted automatically.

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
(`Cmdk.stylesheet_path` — see [Styling](#styling)).

### With Tailwind

Everything composes with a Tailwind v4 setup out of the box: components accept
`class:` attributes like any Phlex element, the runtime needs no build step, and
the shipped themes are plain CSS you can import into your input stylesheet:

```css
@import 'tailwindcss';
@import '../path/to/cmdk-themes.css'; /* copied from Cmdk.stylesheet_path */
```

```ruby
Cmdk::Root(class: 'cmdk-vercel w-full max-w-xl') do ... end
```

No `@source` configuration is needed for the gem — its components emit no
Tailwind utilities of their own. (Heads-up: Tailwind's preflight resets break
native `<dialog>` centering; the runtime ships zero-specificity defaults that
handle this — see [Dialog](#dialog).)

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

React's callbacks are DOM events; all bubble, so listen on the root, the document, or via a
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
pattern — the software keyboard owns the bottom of the screen, so the input
belongs at the top), sized with `dvh` units so dynamic viewports behave. CSS
resets (e.g. Tailwind preflight's universal `margin: 0`) break native `<dialog>`
centering, so the runtime injects these defaults with zero specificity (`:where()`)
— any rule of yours wins, even a bare element selector:

```css
dialog[cmdk-dialog] { margin-top: 30vh; }   /* overrides the default placement */
```

Other mobile defaults: the shipped themes bump the input to 16px under 640px
(prevents iOS Safari's focus zoom), `Cmdk::Input` sets `enterkeyhint="go"` for
the mobile keyboard, and touch-move over items doesn't drag the selection
around while scrolling (only real pointer hover selects).

### Scoped search

cmdk deliberately keeps its filter vanilla; modes like `user: <query>` are userland.
This port gives you both levels:

**Declarative scopes** — declare them on the root, tag items or groups, and offer
scope-entry items for the picker:

```ruby
Cmdk::Root(label: 'Search', scopes: %w[user doc]) do
  div(class: 'cmdk-search-row') { Cmdk::Input() }     # flex row hosts the pill
  Cmdk::List() do
    Cmdk::Item(enters_scope: 'user') { 'Search users…' }
    Cmdk::Group(heading: 'Users', scope: 'user', scope_only: true) { ... }
    Cmdk::Group(heading: 'Docs',  scope: 'doc') { ... }
  end
end
```

The flow follows the Linear/Slack/Raycast pattern (and cmdk's own "pages" recipe):

- Typing `/` suggests the `enters_scope:` items; `/u` narrows them.
- Enter (or click) pins the scope as a **pill** (`[cmdk-scope-pill]`, a button
  inserted before the input) and clears the input — typing then filters only
  items/groups tagged with that `scope:`.
- Typing the name out (`/user `) commits too.
- Backspace on an empty input or clicking the pill leaves the scope.

The root mirrors the state as `data-cmdk-active-scope="user"`, and events carry the
parsed parts — ideal for a server-backed lookup in a Turbo app, since streamed-in
items register automatically:

```js
root.addEventListener('cmdk-scope-change', (e) => {
  if (e.detail.scope === 'user') frame.src = `/search/users?q=${e.detail.query}`
})
```

The picker prefix is configurable (`scope_picker: ':'`) or can be turned off
(`scope_picker: false`). Server-render an already-pinned scope with
`Cmdk::Root(active_scope: 'user')`. Programmatic: `Cmdk.enterScope(root, 'user')` /
`Cmdk.exitScope(root)`.

By default scoped items also match global (unscoped) searches. Mark a group or item
with `scope_only: true` to require deliberate entry — it stays hidden (and excluded
from the result count) unless its scope is active:

```ruby
Cmdk::Group(heading: 'Users', scope: 'user', scope_only: true) { ... }
```

**Fully custom syntax** — the filter function receives the item element as a 4th
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

The runtime fills `[cmdk-footer-hint]` as the selection moves — the hint text in a
`<span>`, each key of `kbd:` as its own `<kbd>` cap — and sets `data-empty` when the
selected item declares no hint. For anything richer, drive your own footer from the
`cmdk-value-change` event.

### Styling

Unstyled, exactly like the React package. Target the attribute contract from Tailwind:

```css
[cmdk-item][data-selected='true'] { @apply bg-neutral-100; }
[cmdk-group-heading]              { @apply px-3 text-xs text-neutral-400; }
[cmdk-list] { height: min(330px, var(--cmdk-list-height)); transition: height 100ms ease; }
```

Three ready-made themes ship with the gem as plain, dependency-free CSS
([assets/css/themes.css](assets/css/themes.css), path via `Cmdk.stylesheet_path`):
`cmdk-vercel`, plus ports of the original cmdk `cmdk-linear` and `cmdk-raycast`
themes. Apply one via the root's class; all are browsable in Lookbook under "Themes".

**Dark mode** — the shipped themes declare every color with `light-dark()` and resolve
through `color-scheme`, giving the standard tri-state:

```css
:root { color-scheme: light dark; }              /* "system": the OS decides */
:root[data-theme='light'] { color-scheme: light; }
:root[data-theme='dark']  { color-scheme: dark; }
```

Leave `data-theme` off (or `system`) to follow the OS preference; set
`<html data-theme="dark">` to force a side — no duplicated selectors, one declaration
per color. The Lookbook previews expose this as a Theme dropdown in the preview toolbar.

## React → Phlex parity map

| React | Here |
|---|---|
| `<Command label shouldFilter loop vimBindings disablePointerSelection defaultValue>` | `Cmdk::Root(label:, should_filter:, loop:, vim_bindings:, disable_pointer_selection:, default_value:)` |
| `<Command value onValueChange>` (controlled) | `Cmdk.setValue(root, v)` + `cmdk-value-change` event |
| `filter={fn}` | `Cmdk.setFilter(fn)` or `Cmdk.setFilter(root, fn)` — same `(value, search, keywords) → 0..1` signature |
| `<Command.Input value onValueChange>` | `Cmdk::Input(value:)`; `Cmdk.setSearch(root, q)`; `cmdk-search-change` |
| `<Command.List label>` | `Cmdk::List(label:)` |
| `<Command.Item value keywords disabled forceMount onSelect>` | `Cmdk::Item(value:, keywords:, disabled:, force_mount:)`; `cmdk-item-select` event; value inferred from text content when omitted |
| `<Command.Group heading value forceMount>` | `Cmdk::Group(heading:, value:, force_mount:)` |
| `<Command.Separator alwaysRender>` | `Cmdk::Separator(always_render:)` |
| `<Command.Empty>` / `<Command.Loading progress label>` | `Cmdk::Empty()` / `Cmdk::Loading(progress:, label:)` |
| `<Command.Dialog open onOpenChange container>` | `Cmdk::Dialog(open:, hotkey:)` — native `<dialog>`, no portal needed |
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

The [Lookbook](https://lookbook.build) previews live in [lookbook/](lookbook/) — Lookbook is a
Rails engine, so a minimal single-file Rails host ([lookbook/app.rb](lookbook/app.rb)) boots it;
the gem itself stays Rails-free. Scenarios cover the default menu (with live params for
placeholder/loop/vim bindings), ungrouped items, `should_filter: false`, force-mounted
items, loading, the empty state, the event log, and the ⌘K dialog.
