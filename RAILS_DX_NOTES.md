# Rails DX improvements (TODO)

Notes from wiring `phlex-cmdk` into a **Sprockets** Rails app and hitting two
`AssetNotPrecompiledError`s (`cmdk.js`, `cmdk_themes.css`). The gem isn't
broken — the friction is Sprockets-specific and the README only documents the
Propshaft path. Two improvements below.

## Background

- The gem is deliberately framework-agnostic: depends only on `phlex`, ships no
  Railtie, exposes `Cmdk.javascript_path` / `Cmdk.stylesheet_path` as the seam.
  Adding those dirs to the asset load path via an initializer is the normal way
  to consume such a gem. Keep that design.
- **Propshaft** (modern Rails default) serves everything on the load path
  automatically → the current README instructions are complete for it.
- **Sprockets** refuses to serve any asset not explicitly declared for
  precompilation → consumer also needs
  `config.assets.precompile += %w[cmdk.js cmdk_themes.css]`. This is the only
  thing that actually errored, and it's undocumented.

## 1. Document the Sprockets case (low effort, high value)

Add to the README, near the existing "With Rails (importmap + Propshaft)"
section — a short callout that Sprockets apps need one extra line:

```ruby
# config/initializers/cmdk.rb (Sprockets only — Propshaft serves these automatically)
Rails.application.config.assets.paths << File.dirname(Cmdk.javascript_path)
Rails.application.config.assets.paths << File.dirname(Cmdk.stylesheet_path)
Rails.application.config.assets.precompile += %w[cmdk.js cmdk_themes.css]
```

## 2. Ship an optional, Rails-guarded Railtie (best DX)

Auto-registers the asset paths **and** precompile entries, so Rails users (on
both Sprockets and Propshaft) write zero initializer code and never see the
precompile error. This is how `turbo-rails` / `stimulus-rails` register their
bundled assets. Core gem stays Rails-free — the `require` is guarded.

```ruby
# lib/cmdk/railtie.rb (loaded only when Rails is present)
module Cmdk
  class Railtie < ::Rails::Railtie
    initializer "cmdk.assets" do |app|
      next unless app.config.respond_to?(:assets)
      app.config.assets.paths << File.dirname(Cmdk.javascript_path)
      app.config.assets.paths << File.dirname(Cmdk.stylesheet_path)
      app.config.assets.precompile += %w[cmdk.js cmdk_themes.css]
    end
  end
end
```

```ruby
# lib/cmdk.rb (bottom)
require_relative "cmdk/railtie" if defined?(Rails::Railtie)
```

**What the Railtie does NOT do** (correctly left to the consumer — these are
app-level choices already covered in the README):

- importmap `pin "cmdk", to: "cmdk.js"`
- `import "cmdk"` in the JS entrypoint
- `stylesheet_link_tag "cmdk_themes"` in the layout

### Suggested follow-ups

- Add a spec for the Railtie (boot a minimal Rails app / assert the initializer
  appends the paths + precompile entries).
- Bump the gem version after adding the Railtie.

## 3. Give the dialog a sensible default min-width

The runtime's `:where(dialog[cmdk-dialog])` defaults use `width: fit-content`,
so a dialog with short content (e.g. a few nav items) renders as a cramped,
narrow palette instead of the expected command-menu width. Consumers currently
have to add their own width (we used a Tailwind `sm:min-w-[36rem]` on the
dialog).

Consider shipping a sensible default `min-width` on the themed dialog frame
(e.g. `.cmdk-dialog-frame`), clamped to the viewport and dropped on the
≤640px mobile sheet — so the out-of-the-box palette looks right without each
consumer rediscovering this. Keep it overridable (a utility/own rule should
still win). Zero-specificity defaults (`:where()`) shrink to content; a themed
class with a `min-width` would set a floor while staying easy to override.

## 4. Document an "external trigger opens the palette" recipe

Very common need: a header search button (or any element outside the dialog)
that opens the `Cmdk::Dialog`. The gem already supports this — the shipped base
controller exposes `open` / `close` / `toggle`, and its `#dialog` getter
resolves `this.element.closest('dialog[cmdk-dialog]') ||
this.element.querySelector('dialog[cmdk-dialog]')` — so wrapping the trigger
**and** the dialog in one `data-controller="cmdk"` is all it takes:

```erb
<div data-controller="cmdk">
  <button data-action="cmdk#open">Suchen…</button>
  <%= render CommandPalette.new %>   <%# renders the <dialog cmdk-dialog> %>
</div>
```

But this isn't shown anywhere: the README documents `open`/`close`/`toggle`
only inside the item-select/scope "With Stimulus" section, so a reader building
a trigger button won't discover it. **Not knowing this, we hand-rolled a whole
controller that just re-implements `open`** (and `window.Cmdk.openDialog` is the
no-Stimulus equivalent):

```js
// What a consumer writes when they miss the shipped `open` action — redundant.
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog"];
  open() { window.Cmdk?.openDialog(this.dialogTarget); }
}
```

Suggested fix: add a short, standalone "Open from your own trigger" recipe to
the README (the 3-line ERB above, plus the `window.Cmdk.openDialog(el)` variant
for importmap/no-Stimulus setups), and call out the `closest()-or-descendant`
dialog resolution so consumers structure the markup correctly.

## Consuming-app cleanup once the Railtie ships

In the app that pulls the new version, the Railtie replaces the manual wiring:

- delete `config/initializers/cmdk.rb`
- drop `cmdk.js` and `cmdk_themes.css` from `config/initializers/assets.rb`
  (`config.assets.precompile`)

Keep: the importmap pin, the `import "cmdk"`, and `stylesheet_link_tag
"cmdk_themes"`.
