module Cmdk
  # Command menu search input. Port of `<Command.Input>` from cmdk.
  # `id`, `aria-controls`, `aria-labelledby` and `aria-activedescendant`
  # are wired up by the JS runtime at init.
  class Input < Base
    # `enterkeyhint:` labels the mobile keyboard's action key (pass nil to omit).
    def initialize(value: nil, enterkeyhint: 'go', **attributes)
      @value = value
      @enterkeyhint = enterkeyhint
      @attributes = attributes
    end

    def view_template
      input(**merged(input_attributes, @attributes))
    end

    private

    def input_attributes
      {
        'cmdk-input' => '',
        type: 'text',
        value: @value,
        autocomplete: 'off',
        autocorrect: 'off',
        spellcheck: 'false',
        role: 'combobox',
        aria_autocomplete: 'list',
        aria_expanded: 'true',
        enterkeyhint: @enterkeyhint
      }
    end
  end
end
