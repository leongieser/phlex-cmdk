module Cmdk
  # Command menu item. Port of `<Command.Item>` from cmdk.
  #
  # Like the React version, `value` is inferred from the rendered text content
  # when not given (the runtime assigns `data-value` at init). `onSelect`
  # becomes a bubbling `cmdk-item-select` CustomEvent with `detail.value`.
  # `href:` is a Turbo-friendly extension: the runtime visits the URL on select.
  class Item < Base
    def initialize(value: nil, keywords: nil, disabled: false, force_mount: false, href: nil,
                   scope: nil, scope_only: false, enters_scope: nil, server_filtered: false,
                   hint: nil, kbd: nil, **attributes)
      @value = value
      @keywords = keywords
      @disabled = disabled
      @force_mount = force_mount
      @href = href
      @scope = scope
      @scope_only = scope_only
      @enters_scope = enters_scope
      @server_filtered = server_filtered
      @hint = hint
      @kbd = kbd
      @attributes = attributes
    end

    def view_template(&block)
      div(**merged(item_attributes, @attributes), &block)
    end

    private

    def item_attributes
      data = { disabled: @disabled.to_s, selected: 'false' }
      data[:value] = @value if @value
      data[:cmdk_keywords] = Array(@keywords).join(' ') if @keywords
      data[:cmdk_force_mount] = '' if @force_mount
      data[:href] = @href if @href
      data[:cmdk_scope] = @scope if @scope
      data[:cmdk_scope_only] = '' if @scope_only
      data[:cmdk_enters_scope] = @enters_scope if @enters_scope
      data[:cmdk_server_filtered] = '' if @server_filtered
      data[:cmdk_hint] = @hint if @hint
      data[:cmdk_kbd] = @kbd if @kbd

      {
        'cmdk-item' => '',
        role: 'option',
        aria_disabled: @disabled.to_s,
        aria_selected: 'false',
        data: data
      }
    end
  end
end
