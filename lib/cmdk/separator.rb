module Cmdk
  # Visual and semantic separator. Port of `<Command.Separator>`.
  # Hidden by the runtime while a search query is present, unless `always_render:`.
  class Separator < Base
    def initialize(always_render: false, **attributes)
      @always_render = always_render
      @attributes = attributes
    end

    def view_template
      defaults = { 'cmdk-separator' => '', role: 'separator' }
      defaults[:data] = { cmdk_always_render: '' } if @always_render
      div(**merged(defaults, @attributes))
    end
  end
end
