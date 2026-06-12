module Cmdk
  # Loading indicator for asynchronous items. Port of `<Command.Loading>`.
  # Conditionally render this yourself while loading, as in React cmdk.
  class Loading < Base
    def initialize(progress: nil, label: 'Loading...', **attributes)
      @progress = progress
      @label = label
      @attributes = attributes
    end

    def view_template(&block)
      defaults = {
        'cmdk-loading' => '',
        role: 'progressbar',
        aria_valuenow: @progress,
        aria_valuemin: '0',
        aria_valuemax: '100',
        aria_label: @label
      }
      div(**merged(defaults, @attributes)) do
        div(aria_hidden: 'true') { block ? block.call : nil }
      end
    end
  end
end
