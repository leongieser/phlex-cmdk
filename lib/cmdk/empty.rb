module Cmdk
  # Shown automatically when there are no results. Port of `<Command.Empty>`.
  # Rendered hidden (inline display:none, so theme CSS cannot override it);
  # the runtime toggles it based on the filtered result count.
  class Empty < Base
    def initialize(**attributes)
      @attributes = attributes
    end

    def view_template(&block)
      defaults = { 'cmdk-empty' => '', role: 'presentation', style: 'display:none' }
      div(**merged(defaults, @attributes)) { block ? block.call : nil }
    end
  end
end
