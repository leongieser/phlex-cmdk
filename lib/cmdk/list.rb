module Cmdk
  # Contains items, groups and separators. Port of `<Command.List>` from cmdk.
  # The JS runtime keeps the `--cmdk-list-height` CSS variable updated on this
  # element so the list height can be animated.
  class List < Base
    def initialize(label: 'Suggestions', **attributes)
      @label = label
      @attributes = attributes
    end

    def view_template(&block)
      div(**merged({ 'cmdk-list' => '', role: 'listbox', tabindex: '-1', aria_label: @label }, @attributes)) do
        div('cmdk-list-sizer' => '', &block)
      end
    end
  end
end
