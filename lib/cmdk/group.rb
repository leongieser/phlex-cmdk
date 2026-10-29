module Cmdk
  # Groups items together with an optional heading. Port of `<Command.Group>`.
  # Provide `value:` when there is no heading (it is used for sorting groups);
  # with a string heading the value is inferred from it, matching React cmdk.
  #
  # `heading_attributes:` and `items_attributes:` add attributes (class,
  # data-*, …) to the heading and to the `[cmdk-group-items]` wrapper; extra
  # keyword attributes go to the group element itself.
  class Group < Base
    # Monotonic id source for `aria-labelledby` (the analog of React's useId,
    # which this port mirrors). Deterministic and collision-free, unlike a
    # random suffix; the mutex keeps it correct under threaded servers.
    @heading_seq = 0
    @heading_mutex = Mutex.new

    def self.next_heading_id
      @heading_mutex.synchronize { "cmdk-heading-#{@heading_seq += 1}" }
    end

    def initialize(heading: nil, value: nil, force_mount: false, scope: nil, scope_only: false,
                   server_filtered: false, heading_attributes: {}, items_attributes: {}, **attributes)
      @heading = heading
      @value = value
      @force_mount = force_mount
      @scope = scope
      @scope_only = scope_only
      @server_filtered = server_filtered
      @heading_attributes = heading_attributes
      @items_attributes = items_attributes
      @attributes = attributes
    end

    def view_template(&block)
      heading_id = @heading ? (@heading_attributes[:id] || Group.next_heading_id) : nil

      div(**merged(group_attributes, @attributes)) do
        if @heading
          div(**merged({ 'cmdk-group-heading' => '', aria_hidden: 'true', id: heading_id }, @heading_attributes)) do
            @heading
          end
        end
        items = { 'cmdk-group-items' => '', role: 'group', aria_labelledby: heading_id }
        div(**merged(items, @items_attributes), &block)
      end
    end

    private

    def group_attributes
      data = {}
      value = @value || (@heading if @heading.is_a?(String))
      data[:value] = value if value
      data[:cmdk_force_mount] = '' if @force_mount
      data[:cmdk_scope] = @scope if @scope
      data[:cmdk_scope_only] = '' if @scope_only
      data[:cmdk_server_filtered] = '' if @server_filtered

      { 'cmdk-group' => '', role: 'presentation', data: data }
    end
  end
end
