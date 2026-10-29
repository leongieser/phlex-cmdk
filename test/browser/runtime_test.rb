require 'minitest/autorun'
require 'json'
require_relative 'support'

# DOM behaviour of the JS runtime in headless Chrome (rake test:browser).
class RuntimeBrowserTest < Minitest::Test
  SERVER = CmdkBrowser::Server.new
  BROWSER = CmdkBrowser.browser
  Minitest.after_run do
    BROWSER.quit
    SERVER.stop
  end

  def teardown
    @page&.close
  end

  # Open `body` in a fresh tab and wait for the runtime to initialise #m.
  # Every page counts CSP violations from its first byte in `window.violations`.
  def visit(body, head: '', headers: {}, wait: 'window.Cmdk?.getState("#m")')
    @page = BROWSER.create_page
    @page.command('Page.addScriptToEvaluateOnNewDocument', source: 'window.violations = []; ' \
                  'document.addEventListener("securitypolicyviolation", (e) => window.violations.push(e.violatedDirective))')
    @page.go_to(SERVER.page("/#{name}", CmdkBrowser.document(body, head: head), headers))
    CmdkBrowser.wait_for(@page, wait)
    @page
  end

  def js(expression, *args)
    @page.evaluate(expression, *args)
  end

  def type(query)
    js("(() => { const i = document.querySelector('#m [cmdk-input]'); i.value = #{query.to_json}; " \
       "i.dispatchEvent(new Event('input', { bubbles: true })) })()")
  end

  # Dispatch a keydown on the input; returns whether the runtime prevented it.
  def keydown(key, **opts)
    js("(() => { const e = new KeyboardEvent('keydown', { key: #{key.to_json}, bubbles: true, cancelable: true, " \
       "...#{opts.to_json} }); document.querySelector('#m [cmdk-input]').dispatchEvent(e); return e.defaultPrevented })()")
  end

  def menu(label: true, **root_options)
    CmdkBrowser.render do
      Cmdk::Root(label: 'Command palette', id: 'm', class: 'cmdk', **root_options) do
        Cmdk::Input()
        Cmdk::List() do
          Cmdk::Empty() { 'No results' }
          Cmdk::Group(heading: 'Collections') do
            Cmdk::Item(value: 'Go to Northwind Journal', data: { create: '/new' }) do
              label ? Cmdk::ItemLabel() { 'Northwind Journal' } : plain('Northwind Journal')
            end
            Cmdk::Item(value: 'Go to Specimens') { label ? Cmdk::ItemLabel() { 'Specimens <b>' } : plain('Specimens <b>') }
            Cmdk::Item(value: 'Go to Media') { 'Media' }
          end
        end
      end
    end
  end

  def dialog_menu
    CmdkBrowser.render do
      Cmdk::Dialog(label: 'Command palette', hotkey: 'k', id: 'm') do
        Cmdk::Input()
        Cmdk::List() { Cmdk::Item() { 'Media' } }
      end
    end
  end

  # ── Base styles and CSP ──

  def test_base_styles_are_injected_by_default
    visit(menu)

    assert js('!!document.getElementById("cmdk-base-styles")')
    assert_equal '', js('document.getElementById("cmdk-base-styles").nonce')
    refute_includes js('document.getElementById("cmdk-base-styles").textContent'), '@layer'
  end

  def test_base_styles_take_the_csp_nonce_and_apply_under_a_strict_csp
    csp = "default-src 'self'; style-src 'nonce-n0nce'; script-src 'self'"
    visit(dialog_menu, head: '<meta name="csp-nonce" content="n0nce">',
                       headers: { 'Content-Security-Policy' => csp })
    js('window.Cmdk.openDialog("#m")')

    assert_equal 'n0nce', js('document.getElementById("cmdk-base-styles").nonce')
    assert_equal [], js('window.violations')
    assert_equal 'fixed', js('getComputedStyle(document.querySelector("dialog[cmdk-dialog]")).position')
  end

  def test_base_styles_can_be_turned_off
    visit(menu, head: '<meta name="cmdk-base-styles" content="off">')

    refute js('!!document.getElementById("cmdk-base-styles")')
  end

  def test_base_styles_can_be_layered
    visit(menu, head: '<meta name="cmdk-base-styles" content="layer">')
    assert js('document.getElementById("cmdk-base-styles").textContent').start_with?('@layer cmdk {')
  end

  def test_base_styles_can_go_into_a_named_layer
    visit(menu, head: '<meta name="cmdk-base-styles" content="layer:vendor">')
    assert js('document.getElementById("cmdk-base-styles").textContent').start_with?('@layer vendor {')
  end

  def test_static_base_stylesheet_works_with_injection_off
    visit(dialog_menu, head: '<meta name="cmdk-base-styles" content="off"><link rel="stylesheet" href="/cmdk_base.css">')
    js('window.Cmdk.openDialog("#m")')

    refute js('!!document.getElementById("cmdk-base-styles")')
    assert_equal 'fixed', js('getComputedStyle(document.querySelector("dialog[cmdk-dialog]")).position')
  end

  def test_markup_needs_no_inline_styles_under_a_strict_csp
    visit(menu, head: '<meta name="cmdk-base-styles" content="off">' \
                      '<link rel="stylesheet" href="/cmdk_base.css"><link rel="stylesheet" href="/cmdk_themes.css">',
                headers: { 'Content-Security-Policy' => "default-src 'self'; style-src 'self'" })

    refute js('document.querySelector("#m [cmdk-label]").checkVisibility()')
    refute js('document.querySelector("#m [cmdk-empty]").checkVisibility()')
    type('zzz')
    assert js('document.querySelector("#m [cmdk-empty]").checkVisibility()')
    type('')
    refute js('document.querySelector("#m [cmdk-empty]").checkVisibility()')
    assert_equal [], js('window.violations')
  end

  def test_an_un_nonced_injection_is_what_a_strict_csp_would_block
    visit(menu, headers: { 'Content-Security-Policy' => "default-src 'self'; style-src 'self'" })

    # Without the nonce meta or the opt-out, the injected <style> is refused:
    # the documented reason for both.
    assert_includes js('window.violations'), 'style-src-elem'
  end

  def test_hidden_label_still_names_the_input
    visit(menu)
    nodes = @page.command('Accessibility.getFullAXTree')['nodes']
    combobox = nodes.find { |n| n.dig('role', 'value') == 'combobox' }

    assert_equal 'Command palette', combobox.dig('name', 'value')
    assert_equal js('document.querySelector("#m [cmdk-label]").id'),
                 js('document.querySelector("#m [cmdk-input]").getAttribute("aria-labelledby")')
  end

  def test_empty_stays_hidden_while_themes_set_display
    visit(menu, head: '<link rel="stylesheet" href="/cmdk_themes.css">')

    refute js('document.querySelector("#m [cmdk-empty]").checkVisibility()')
    type('qqq')
    assert js('document.querySelector("#m [cmdk-empty]").checkVisibility()')
  end

  # ── Match highlighting ──

  def label_html(value)
    js("document.querySelector('#m [data-value=#{value.to_json}] [cmdk-item-label]').innerHTML")
  end

  def test_highlights_matches_in_item_labels
    visit(menu)
    type('nj')

    assert_equal '<mark cmdk-match="">N</mark>orthwind <mark cmdk-match="">J</mark>ournal',
                 label_html('Go to Northwind Journal')
    assert_equal 'Northwind Journal',
                 js('document.querySelector("#m [data-value=\'Go to Northwind Journal\'] [cmdk-item-label]").textContent')
  end

  def test_highlight_runs_are_merged_and_text_is_never_parsed_as_html
    visit(menu)
    type('spec')

    assert_equal '<mark cmdk-match="">Spec</mark>imens &lt;b&gt;', label_html('Go to Specimens')
    assert_equal 0, js('document.querySelectorAll("#m [cmdk-item-label] b").length')
  end

  def test_highlights_are_removed_when_the_search_clears
    visit(menu)
    type('nj')
    type('')

    assert_equal 'Northwind Journal', label_html('Go to Northwind Journal')
    assert_equal 0, js('document.querySelectorAll("#m mark").length')
  end

  def test_marks_left_by_an_earlier_instance_are_cleared
    visit(menu)
    type('nj')
    js('window.Cmdk.destroy("#m"); window.Cmdk.scan(document)') # e.g. a page restored from Turbo's cache
    type('')

    assert_equal 'Northwind Journal', label_html('Go to Northwind Journal')
  end

  def test_items_without_a_label_element_are_left_alone
    visit(menu)
    type('med')

    assert_equal 'Media', js('document.querySelector("#m [data-value=\'Go to Media\']").innerHTML')
  end

  def test_no_highlighting_without_the_opt_in_markup
    visit(menu(label: false))
    type('nj')

    assert_equal 0, js('document.querySelectorAll("#m mark").length')
  end

  # ── Select event modifiers ──

  def capture_select
    js('window.selected = []; document.addEventListener("cmdk-item-select", (e) => { ' \
       'e.preventDefault(); window.selected.push(e.detail) })')
  end

  def test_enter_reports_modifier_keys
    visit(menu)
    capture_select
    keydown('Enter', metaKey: true)
    keydown('Enter', ctrlKey: true, shiftKey: true)
    keydown('Enter')

    assert_equal [
      { 'value' => 'Go to Northwind Journal', 'metaKey' => true, 'ctrlKey' => false, 'shiftKey' => false, 'altKey' => false },
      { 'value' => 'Go to Northwind Journal', 'metaKey' => false, 'ctrlKey' => true, 'shiftKey' => true, 'altKey' => false },
      { 'value' => 'Go to Northwind Journal', 'metaKey' => false, 'ctrlKey' => false, 'shiftKey' => false, 'altKey' => false }
    ], js('window.selected')
  end

  def test_click_reports_modifier_keys
    visit(menu)
    capture_select
    js('document.querySelector("#m [data-value=\'Go to Media\']").dispatchEvent(' \
       'new MouseEvent("click", { bubbles: true, altKey: true }))')

    assert_equal [{ 'value' => 'Go to Media', 'metaKey' => false, 'ctrlKey' => false, 'shiftKey' => false, 'altKey' => true }],
                 js('window.selected')
  end

  # ── Teardown ──

  def append_item(text)
    js("(() => { const d = document.createElement('div'); d.setAttribute('cmdk-item', ''); d.textContent = #{text.to_json}; " \
       "document.querySelector('#m [cmdk-group-items]').appendChild(d) })()")
    js('new Promise((r) => setTimeout(r, 0))')
  end

  def test_destroy_disconnects_and_a_later_scan_reinitialises
    visit(menu)
    js('window.Cmdk.destroy("#m")')
    append_item('Go to Authors')

    # Not observed any more: the new item was not registered.
    refute js('document.querySelector("#m [cmdk-item]:last-child").hasAttribute("data-value")')

    js('window.Cmdk.scan(document)')
    assert_equal 'Go to Authors', js('document.querySelector("#m [cmdk-item]:last-child").getAttribute("data-value")')
    append_item('Go to Places')
    assert_equal 'Go to Places', js('document.querySelector("#m [cmdk-item]:last-child").getAttribute("data-value")')
    type('places')
    assert_equal 'Go to Places', js('window.Cmdk.getState("#m").value')
  end

  def test_destroy_without_an_instance_is_a_no_op
    visit(menu)
    js('window.Cmdk.destroy("#m"); window.Cmdk.destroy("#m"); window.Cmdk.destroy("#nothing")')
  end

  # ── Keyboard extras ──

  def test_home_and_end_select_first_and_last_by_default
    visit(menu)

    assert keydown('End')
    assert_equal 'Go to Media', js('window.Cmdk.getState("#m").value')
    assert keydown('Home')
    assert_equal 'Go to Northwind Journal', js('window.Cmdk.getState("#m").value')
  end

  def test_native_home_end_leaves_the_caret_keys_to_the_input
    visit(menu(native_home_end: true))

    refute keydown('End')
    assert_equal 'Go to Northwind Journal', js('window.Cmdk.getState("#m").value')
  end

  def hotkey(key, code, **opts)
    js("document.body.dispatchEvent(new KeyboardEvent('keydown', { key: #{key.to_json}, code: #{code.to_json}, " \
       "bubbles: true, cancelable: true, ...#{opts.to_json} }))")
    js('document.querySelector("dialog[cmdk-dialog]").open')
  end

  def test_hotkey_matches_the_physical_key_on_non_latin_layouts
    visit(dialog_menu)

    assert hotkey('л', 'KeyK', metaKey: true) # Cyrillic layout
    refute hotkey('л', 'KeyK', ctrlKey: true)
  end

  def test_hotkey_keeps_matching_latin_layouts_by_key
    visit(dialog_menu)

    refute hotkey('t', 'KeyK', metaKey: true) # Dvorak: the K position types "t"
    assert hotkey('k', 'KeyT', metaKey: true) # Dvorak: "k" sits elsewhere
  end

  def test_open_dialogs_close_before_turbo_caches_the_page
    visit(dialog_menu)
    js('window.Cmdk.openDialog("#m")')
    js('document.dispatchEvent(new Event("turbo:before-cache"))')

    refute js('document.querySelector("dialog[cmdk-dialog]").open')
  end
end
