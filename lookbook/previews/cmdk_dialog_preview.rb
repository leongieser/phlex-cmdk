# @label Command Dialog
#
# The command menu inside a native `<dialog>` — the port of `<Command.Dialog>`.
class CmdkDialogPreview < Lookbook::Preview
  # Opens as a modal: click the button or press ⌘K / Ctrl+K.
  # Escape and backdrop clicks close it.
  def default
    render Scenarios::Dialog.new
  end
end
