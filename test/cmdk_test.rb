require 'minitest/autorun'
require_relative '../lib/cmdk'

# Renders a block as a Phlex view so kit methods (Cmdk::Item(...)) work.
def render(&block)
  Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
end

class RootTest < Minitest::Test
  def test_renders_markup_contract
    html = render do
      Cmdk::Root(label: 'Menu') { Cmdk::Input() }
    end

    assert_includes html, 'cmdk-root=""'
    assert_includes html, 'tabindex="-1"'
    assert_includes html, '<label cmdk-label='
    assert_includes html, '>Menu</label>'
    # Accessible label is visually hidden, like React's srOnlyStyles
    assert_includes html, 'position:absolute;width:1px;height:1px'
  end

  def test_options_become_data_attributes
    html = render do
      Cmdk::Root(should_filter: false, loop: true, vim_bindings: false,
                 disable_pointer_selection: true, default_value: 'b')
    end

    assert_includes html, 'data-cmdk-should-filter="false"'
    assert_includes html, 'data-cmdk-loop=""'
    assert_includes html, 'data-cmdk-vim-bindings="false"'
    assert_includes html, 'data-cmdk-disable-pointer-selection=""'
    assert_includes html, 'data-cmdk-default-value="b"'
  end

  def test_defaults_render_no_data_attributes
    html = render { Cmdk::Root() }

    refute_includes html, 'data-cmdk-should-filter'
    refute_includes html, 'data-cmdk-loop'
    refute_includes html, 'data-cmdk-vim-bindings'
  end

  def test_merges_custom_attributes
    html = render { Cmdk::Root(class: 'raycast', id: 'menu') }

    assert_includes html, 'class="raycast"'
    assert_includes html, 'id="menu"'
  end

  def test_scopes_as_names
    html = render { Cmdk::Root(scopes: %w[user doc]) }

    assert_includes html, 'data-cmdk-scopes="user doc"'
  end

  def test_active_scope_for_ssr
    html = render { Cmdk::Root(scopes: %w[user doc], active_scope: 'user') }

    assert_includes html, 'data-cmdk-active-scope="user"'
  end

  def test_scope_picker_override_and_disable
    html = render { Cmdk::Root(scopes: %w[user], scope_picker: ':') }
    assert_includes html, 'data-cmdk-scope-picker=":"'

    html = render { Cmdk::Root(scopes: %w[user], scope_picker: false) }
    assert_includes html, 'data-cmdk-scope-picker="false"'

    html = render { Cmdk::Root(scopes: %w[user]) }
    refute_includes html, 'data-cmdk-scope-picker'
  end
end

class InputTest < Minitest::Test
  def test_renders_combobox_contract
    html = render { Cmdk::Input(placeholder: 'Search...') }

    assert_includes html, 'cmdk-input=""'
    assert_includes html, 'role="combobox"'
    assert_includes html, 'aria-autocomplete="list"'
    assert_includes html, 'aria-expanded="true"'
    assert_includes html, 'autocomplete="off"'
    assert_includes html, 'spellcheck="false"'
    assert_includes html, 'placeholder="Search..."'
  end
end

class ListTest < Minitest::Test
  def test_renders_listbox_with_sizer
    html = render { Cmdk::List() { Cmdk::Item { 'A' } } }

    assert_includes html, 'cmdk-list=""'
    assert_includes html, 'role="listbox"'
    assert_includes html, 'aria-label="Suggestions"'
    assert_includes html, 'cmdk-list-sizer=""'
  end
end

class ItemTest < Minitest::Test
  def test_renders_option_contract
    html = render { Cmdk::Item { 'Apple' } }

    assert_includes html, 'cmdk-item=""'
    assert_includes html, 'role="option"'
    assert_includes html, 'aria-disabled="false"'
    assert_includes html, 'aria-selected="false"'
    assert_includes html, 'data-disabled="false"'
    assert_includes html, 'data-selected="false"'
    assert_includes html, '>Apple</div>'
  end

  def test_value_keywords_disabled_force_mount
    html = render do
      Cmdk::Item(value: 'apple', keywords: %w[fruit red], disabled: true, force_mount: true) { 'Apple' }
    end

    assert_includes html, 'data-value="apple"'
    assert_includes html, 'data-cmdk-keywords="fruit red"'
    assert_includes html, 'aria-disabled="true"'
    assert_includes html, 'data-disabled="true"'
    assert_includes html, 'data-cmdk-force-mount=""'
  end

  def test_href_extension
    html = render { Cmdk::Item(href: '/settings') { 'Settings' } }

    assert_includes html, 'data-href="/settings"'
  end

  def test_scope
    html = render { Cmdk::Item(scope: 'user') { 'Leon' } }

    assert_includes html, 'data-cmdk-scope="user"'
    refute_includes html, 'data-cmdk-scope-only'
  end

  def test_scope_only
    html = render { Cmdk::Item(scope: 'user', scope_only: true) { 'Leon' } }

    assert_includes html, 'data-cmdk-scope-only=""'
  end

  def test_enters_scope
    html = render { Cmdk::Item(enters_scope: 'user') { 'Search users…' } }

    assert_includes html, 'data-cmdk-enters-scope="user"'
  end

  def test_hint_and_kbd
    html = render { Cmdk::Item(hint: 'Open in New Tab', kbd: '⌘ ↵') { 'Figma' } }

    assert_includes html, 'data-cmdk-hint="Open in New Tab"'
    assert_includes html, 'data-cmdk-kbd="⌘ ↵"'
  end
end

class FooterTest < Minitest::Test
  def test_renders_hint_container_by_default
    html = render { Cmdk::Footer() }

    assert_includes html, 'cmdk-footer=""'
    assert_includes html, 'cmdk-footer-hint=""'
  end

  def test_custom_content
    html = render { Cmdk::Footer(class: 'bar') { 'Custom' } }

    assert_includes html, 'class="bar"'
    assert_includes html, 'Custom'
    refute_includes html, 'cmdk-footer-hint'
  end
end

class GroupTest < Minitest::Test
  def test_renders_heading_and_items_container
    html = render { Cmdk::Group(heading: 'Fruits') { Cmdk::Item { 'Apple' } } }

    assert_includes html, 'cmdk-group=""'
    assert_includes html, 'role="presentation"'
    assert_includes html, 'data-value="Fruits"'
    assert_includes html, 'cmdk-group-heading=""'
    assert_includes html, 'aria-hidden="true"'
    assert_includes html, 'cmdk-group-items=""'
    assert_includes html, 'role="group"'
    assert_match(/aria-labelledby="cmdk-heading-\h{8}"/, html)
  end

  def test_without_heading_uses_explicit_value
    html = render { Cmdk::Group(value: 'misc') { Cmdk::Item { 'A' } } }

    assert_includes html, 'data-value="misc"'
    refute_includes html, 'cmdk-group-heading'
    refute_includes html, 'aria-labelledby'
  end

  def test_scope
    html = render { Cmdk::Group(heading: 'Users', scope: 'user') { Cmdk::Item { 'Leon' } } }

    assert_includes html, 'data-cmdk-scope="user"'
  end

  def test_scope_only
    html = render { Cmdk::Group(heading: 'Users', scope: 'user', scope_only: true) { Cmdk::Item { 'Leon' } } }

    assert_includes html, 'data-cmdk-scope-only=""'
  end
end

class SeparatorTest < Minitest::Test
  def test_renders_separator
    html = render { Cmdk::Separator() }

    assert_includes html, 'cmdk-separator=""'
    assert_includes html, 'role="separator"'
    refute_includes html, 'data-cmdk-always-render'
  end

  def test_always_render
    html = render { Cmdk::Separator(always_render: true) }

    assert_includes html, 'data-cmdk-always-render=""'
  end
end

class EmptyTest < Minitest::Test
  def test_renders_hidden_by_default
    html = render { Cmdk::Empty { 'No results found.' } }

    assert_includes html, 'cmdk-empty=""'
    assert_includes html, 'role="presentation"'
    assert_includes html, 'style="display:none"'
    assert_includes html, 'No results found.'
  end
end

class LoadingTest < Minitest::Test
  def test_renders_progressbar
    html = render { Cmdk::Loading(progress: 50) { 'Fetching...' } }

    assert_includes html, 'cmdk-loading=""'
    assert_includes html, 'role="progressbar"'
    assert_includes html, 'aria-valuenow="50"'
    assert_includes html, 'aria-valuemin="0"'
    assert_includes html, 'aria-valuemax="100"'
    assert_includes html, 'aria-label="Loading..."'
    assert_includes html, '<div aria-hidden="true">Fetching...</div>'
  end
end

class DialogTest < Minitest::Test
  def test_renders_native_dialog_wrapping_root
    html = render do
      Cmdk::Dialog(label: 'Command Menu', hotkey: 'k', loop: true) { Cmdk::Input() }
    end

    assert_includes html, '<dialog cmdk-dialog=""'
    assert_includes html, 'aria-label="Command Menu"'
    assert_includes html, 'data-cmdk-dialog-hotkey="k"'
    assert_includes html, 'cmdk-root=""'
    assert_includes html, 'data-cmdk-loop=""'
    assert_includes html, 'cmdk-input=""'
  end

  def test_open_renders_open_marker
    html = render { Cmdk::Dialog(open: true) }

    assert_includes html, 'data-cmdk-open=""'
  end
end

class JavascriptTest < Minitest::Test
  def test_runtime_asset_exists
    assert File.exist?(Cmdk.javascript_path)
    assert_includes File.read(Cmdk.javascript_path), 'commandScore'
  end
end
