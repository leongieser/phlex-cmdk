module Cmdk
  # Shared base for all cmdk components.
  class Base < ::Phlex::HTML
    # Inline equivalent of cmdk's srOnlyStyles, used for the accessible label.
    SR_ONLY_STYLE = 'position:absolute;width:1px;height:1px;padding:0;margin:-1px;' \
                    'overflow:hidden;clip:rect(0, 0, 0, 0);white-space:nowrap;border-width:0'.freeze

    private

    # Merge user-supplied attributes into the component's defaults.
    # User values win, except `class` and `style` which are concatenated
    # and `data` hashes which are merged.
    #
    # Deliberately not Phlex's `mix`: `mix` treats *every* attribute as a
    # token list (e.g. `mix({role: 'option'}, {role: 'button'})` yields
    # `role: 'option button'`), which is wrong for scalar attributes like
    # `role`/`type`/`tabindex`/`aria-selected` that should be replaced, not
    # appended. Here only `class`/`style`/`data` combine; other scalars override.
    def merged(defaults, overrides)
      defaults.merge(overrides) do |key, default, override|
        case key
        when :class then [default, override].compact.join(' ')
        when :style then [default.to_s.chomp(';'), override].compact.join(';')
        when :data then default.is_a?(Hash) && override.is_a?(Hash) ? default.merge(override) : override
        else override
        end
      end
    end
  end
end
