module Cmdk
  # Shown automatically when there are no results. Port of `<Command.Empty>`.
  # Rendered with the `hidden` attribute (no inline style, so it works under a
  # strict CSP); the runtime toggles it based on the filtered result count,
  # with an inline display so theme CSS cannot override it. If your own CSS
  # sets `display` on `[cmdk-empty]`, add `[cmdk-empty][hidden] { display:
  # none }` so it stays hidden before the runtime starts (the shipped themes
  # and base styles do this).
  class Empty < Base
    def initialize(**attributes)
      @attributes = attributes
    end

    def view_template(&block)
      defaults = { 'cmdk-empty' => '', role: 'presentation', hidden: true }
      div(**merged(defaults, @attributes), &block)
    end
  end
end
