# @label Command Menu
#
# Previews for the cmdk-phlex command menu — a Phlex port of the cmdk React component.
class CmdkPreview < Lookbook::Preview
  # The full command menu: groups, separator, keywords, a disabled item.
  # Try typing to filter, arrow keys / ctrl+n/p to navigate, Enter to select.
  #
  # @label Default
  # @param placeholder text
  # @param loop toggle "Wrap around when arrowing past the ends"
  # @param vim_bindings toggle "ctrl+n/j/p/k navigation"
  # @param disable_pointer_selection toggle "Ignore pointer hover selection"
  def default(placeholder: 'What do you need?', loop: true, vim_bindings: true, disable_pointer_selection: false)
    render Scenarios::Menu.new(
      placeholder: placeholder,
      loop: bool(loop),
      vim_bindings: bool(vim_bindings),
      disable_pointer_selection: bool(disable_pointer_selection),
    )
  end

  # Items without groups; values are inferred from each item's text content,
  # exactly like the React version.
  def plain_items
    render Scenarios::PlainItems.new
  end

  # `should_filter: false` turns off filtering and sorting — useful when the
  # server filters items instead (e.g. re-rendering the list via Turbo).
  def without_filtering
    render Scenarios::Menu.new(should_filter: false, placeholder: 'Filtering disabled — items never hide')
  end

  # Force-mounted groups and items ignore filtering and always stay visible.
  # The separator uses `always_render: true`.
  def force_mount
    render Scenarios::ForceMount.new
  end

  # Render `Cmdk::Loading` while fetching items asynchronously.
  #
  # @param progress number
  def loading(progress: 50)
    render Scenarios::Loading.new(progress: progress.to_i)
  end

  # With no items rendered, `Cmdk::Empty` shows immediately.
  def empty
    render Scenarios::Empty.new
  end

  # Scoped search (extension over the React API): typing `/` suggests the
  # `enters_scope:` items; Enter pins the scope as a pill before the input and
  # the remaining text only matches items/groups tagged with that `scope:`.
  # Typing a trigger out (`/user ` or `user: `) commits the pill too;
  # Backspace on an empty input or a pill click leaves the scope.
  # `cmdk-scope-change` fires for server-backed lookups via Turbo.
  def scoped_search
    render Scenarios::ScopedSearch.new
  end

  # All React callbacks are DOM events here: cmdk-item-select, cmdk-value-change
  # and cmdk-search-change bubble up from the root. Interact with the menu and
  # watch the log below.
  def events
    render Scenarios::Events.new
  end

  private

  # Lookbook delivers toggle params as strings.
  def bool(value)
    value.to_s != 'false'
  end
end
