module Cmdk
  # Command menu search input. Port of `<Command.Input>` from cmdk.
  # `id`, `aria-controls`, `aria-labelledby` and `aria-activedescendant`
  # are wired up by the JS runtime at init.
  class Input < Base
    def initialize(value: nil, **attributes)
      @value = value
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
        aria_expanded: 'true'
      }
    end
  end
end
