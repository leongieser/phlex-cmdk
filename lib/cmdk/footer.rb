module Cmdk
  # Palette footer, as seen in Raycast-style command menus (an extension over
  # the React API). Render any content; include an element with the
  # `cmdk-footer-hint` attribute (or pass no block to get one) and the runtime
  # fills it with the selected item's `hint:` text and `kbd:` keys:
  #
  #   Cmdk::Item(hint: 'Open in New Tab', kbd: '⌘ ↵') { 'Figma' }
  #
  #   Cmdk::Footer() do
  #     span { '🚀' }
  #     div('cmdk-footer-hint' => '')
  #   end
  #
  # The hint container gets `data-empty` when the selected item has no hint.
  class Footer < Base
    def initialize(**attributes)
      @attributes = attributes
    end

    def view_template(&block)
      div(**merged({ 'cmdk-footer' => '' }, @attributes)) do
        if block
          block.call
        else
          div('cmdk-footer-hint' => '')
        end
      end
    end
  end
end
