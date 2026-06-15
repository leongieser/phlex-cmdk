module Cmdk
  # Command menu root. Port of `<Command>` from cmdk.
  #
  # React props map to data attributes consumed by the JS runtime:
  # shouldFilter, loop, vimBindings, disablePointerSelection, defaultValue.
  # `onValueChange` becomes a bubbling `cmdk-value-change` CustomEvent;
  # a custom `filter` can be registered via `Cmdk.setFilter(rootEl, fn)` in JS.
  #
  # `scopes:` enables scoped search (an extension over the React API): pass
  # scope names (`scopes: %w[user doc]`). Typing the scope-picker prefix
  # ("/" by default, override with `scope_picker: ':'`, disable with
  # `scope_picker: false`) suggests `Cmdk::Item(enters_scope:)` items;
  # committing one — or typing the name out ("/user ") — pins the scope as a
  # pill before the input. The rest of the input is then matched only against
  # items/groups tagged with the same `scope:`. Pass `active_scope:` to
  # server-render an already-pinned scope.
  class Root < Base
    def initialize(label: nil, default_value: nil, should_filter: true, loop: false,
                   vim_bindings: true, disable_pointer_selection: false, scopes: nil,
                   scope_picker: nil, active_scope: nil, **attributes)
      @label = label
      @default_value = default_value
      @should_filter = should_filter
      @loop = loop
      @vim_bindings = vim_bindings
      @disable_pointer_selection = disable_pointer_selection
      @scopes = scopes
      @scope_picker = scope_picker
      @active_scope = active_scope
      @attributes = attributes
    end

    def view_template(&block)
      div(**merged(root_attributes, @attributes)) do
        label('cmdk-label' => '', style: SR_ONLY_STYLE) { @label }
        block&.call
      end
    end

    private

    def root_attributes
      data = {}
      data[:cmdk_should_filter] = 'false' unless @should_filter
      data[:cmdk_loop] = '' if @loop
      data[:cmdk_vim_bindings] = 'false' unless @vim_bindings
      data[:cmdk_disable_pointer_selection] = '' if @disable_pointer_selection
      data[:cmdk_default_value] = @default_value if @default_value
      data[:cmdk_scopes] = Array(@scopes).join(' ') if @scopes
      data[:cmdk_active_scope] = @active_scope if @active_scope
      unless @scope_picker.nil?
        data[:cmdk_scope_picker] = @scope_picker == false ? 'false' : @scope_picker
      end

      { 'cmdk-root' => '', tabindex: '-1', data: data }
    end
  end
end
