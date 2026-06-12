require 'securerandom'

module Cmdk
  # Groups items together with an optional heading. Port of `<Command.Group>`.
  # Provide `value:` when there is no heading (it is used for sorting groups);
  # with a string heading the value is inferred from it, matching React cmdk.
  class Group < Base
    def initialize(heading: nil, value: nil, force_mount: false, **attributes)
      @heading = heading
      @value = value
      @force_mount = force_mount
      @attributes = attributes
    end

    def view_template(&block)
      heading_id = @heading ? "cmdk-heading-#{SecureRandom.hex(4)}" : nil

      div(**merged(group_attributes, @attributes)) do
        if @heading
          div('cmdk-group-heading' => '', aria_hidden: 'true', id: heading_id) { @heading }
        end
        div('cmdk-group-items' => '', role: 'group', aria_labelledby: heading_id) do
          block ? block.call : nil
        end
      end
    end

    private

    def group_attributes
      data = {}
      value = @value || (@heading if @heading.is_a?(String))
      data[:value] = value if value
      data[:cmdk_force_mount] = '' if @force_mount

      { 'cmdk-group' => '', role: 'presentation', data: data }
    end
  end
end
