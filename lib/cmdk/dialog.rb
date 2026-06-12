module Cmdk
  # Command menu inside a native <dialog>. Port of `<Command.Dialog>`.
  #
  # Replaces the Radix dialog with a native modal dialog: Escape closes it
  # natively, clicking the backdrop closes it via the runtime, and the
  # backdrop is styled with `dialog[cmdk-dialog]::backdrop` instead of
  # `[cmdk-overlay]`. Accepts every `Cmdk::Root` option plus:
  #
  # - `open:` render the page with the dialog already open (runtime calls showModal)
  # - `hotkey:` a key like "k" — the runtime toggles the dialog on cmd/ctrl+key
  class Dialog < Base
    def initialize(open: false, hotkey: nil, label: nil, default_value: nil, should_filter: true,
                   loop: false, vim_bindings: true, disable_pointer_selection: false,
                   dialog_attributes: {}, **attributes)
      @open = open
      @hotkey = hotkey
      @dialog_attributes = dialog_attributes
      @root_options = {
        label: label, default_value: default_value, should_filter: should_filter, loop: loop,
        vim_bindings: vim_bindings, disable_pointer_selection: disable_pointer_selection
      }
      @attributes = attributes
    end

    def view_template(&block)
      data = {}
      data[:cmdk_open] = '' if @open
      data[:cmdk_dialog_hotkey] = @hotkey if @hotkey

      dialog(**merged({ 'cmdk-dialog' => '', aria_label: @root_options[:label], data: data }, @dialog_attributes)) do
        render Root.new(**@root_options, **@attributes), &block
      end
    end
  end
end
