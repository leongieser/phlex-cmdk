# Phlex views rendered by the Lookbook previews in lookbook/previews/.
# Each scenario is a small composition of Cmdk components, styled with the
# demo's `cmdk-vercel` Tailwind theme.
module Scenarios
  class Menu < Phlex::HTML
    def initialize(placeholder: 'What do you need?', loop: true, vim_bindings: true,
                   disable_pointer_selection: false, should_filter: true)
      @placeholder = placeholder
      @loop = loop
      @vim_bindings = vim_bindings
      @disable_pointer_selection = disable_pointer_selection
      @should_filter = should_filter
    end

    def view_template
      Cmdk::Root(label: 'Command Menu', loop: @loop, vim_bindings: @vim_bindings,
                 disable_pointer_selection: @disable_pointer_selection, should_filter: @should_filter,
                 class: 'cmdk-vercel w-160 max-w-full') do
        Cmdk::Input(placeholder: @placeholder)
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }

          Cmdk::Group(heading: 'Suggestions') do
            Cmdk::Item(value: 'Linear', keywords: %w[issue tracker]) { item('📐', 'Linear') }
            Cmdk::Item(value: 'Figma', keywords: %w[design]) { item('🎨', 'Figma') }
            Cmdk::Item(value: 'Slack', keywords: %w[chat team]) { item('💬', 'Slack') }
            Cmdk::Item(value: 'YouTube', keywords: %w[video]) { item('📺', 'YouTube') }
            Cmdk::Item(value: 'Raycast', keywords: %w[launcher]) { item('🚀', 'Raycast') }
          end

          Cmdk::Separator()

          Cmdk::Group(heading: 'Settings') do
            Cmdk::Item(value: 'Change Theme', keywords: %w[appearance]) { item('🌗', 'Change Theme') }
            Cmdk::Item(value: 'Admin Settings', disabled: true) { item('🔒', 'Admin Settings (disabled)') }
          end
        end
      end
    end

    private

    def item(icon, text)
      span(class: 'text-base', aria_hidden: 'true') { icon }
      span { text }
    end
  end

  class PlainItems < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Fruits', class: 'cmdk-vercel w-160 max-w-full') do
        Cmdk::Input(placeholder: 'Search fruit...')
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }
          %w[Apple Banana Cherry Grape Orange Peach].each do |fruit|
            Cmdk::Item() { fruit } # value inferred from text content
          end
        end
      end
    end
  end

  class ForceMount < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Force mount', class: 'cmdk-vercel w-160 max-w-full') do
        Cmdk::Input(placeholder: "Type 'zzz': Help stays visible")
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }
          Cmdk::Group(heading: 'Results') do
            Cmdk::Item() { 'Open Project' }
            Cmdk::Item() { 'Close Project' }
          end
          Cmdk::Group(heading: 'Always here', force_mount: true) do
            Cmdk::Item(value: 'Help') { '❓ Help (force mounted)' }
          end
          Cmdk::Separator(always_render: true)
          Cmdk::Item(value: 'Quit', force_mount: true) { '🚪 Quit (force mounted)' }
        end
      end
    end
  end

  class Loading < Phlex::HTML
    def initialize(progress: 50)
      @progress = progress
    end

    def view_template
      Cmdk::Root(label: 'Loading', class: 'cmdk-vercel w-160 max-w-full') do
        Cmdk::Input(placeholder: 'Fetching results...')
        Cmdk::List() do
          Cmdk::Loading(progress: @progress) { 'Hang on, loading results…' }
        end
      end
    end
  end

  class Empty < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Empty', class: 'cmdk-vercel w-160 max-w-full') do
        Cmdk::Input(placeholder: 'No items were rendered at all')
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }
        end
      end
    end
  end

  class Dialog < Phlex::HTML
    def view_template
      div(class: 'flex flex-col items-center gap-4') do
        button(
          id: 'cmdk-dialog-trigger',
          class: 'demo-panel px-4 py-2 text-sm shadow-sm',
        ) { 'Open Command Menu' }
        p(class: 'demo-hint flex items-center gap-1 text-xs') do
          plain 'or press'
          kbd(class: 'demo-kbd') { '⌘' }
          kbd(class: 'demo-kbd') { 'K' }
          plain '/'
          kbd(class: 'demo-kbd') { 'Ctrl' }
          kbd(class: 'demo-kbd') { 'K' }
          plain '. Esc or backdrop click closes.'
        end
        script { raw safe(<<~JS) }
          document.getElementById('cmdk-dialog-trigger').addEventListener('click', () => {
            Cmdk.openDialog(document.querySelector('dialog[cmdk-dialog]'))
          })
        JS

        Cmdk::Dialog(label: 'Command Menu', hotkey: 'k', loop: true,
                     dialog_attributes: { class: 'cmdk-dialog-frame' },
                     class: 'cmdk-vercel w-144 max-w-full') do
          Cmdk::Input(placeholder: 'Type a command or search...')
          Cmdk::List() do
            Cmdk::Empty() { 'No results found.' }
            Cmdk::Group(heading: 'Actions') do
              Cmdk::Item(value: 'New File') { '📄 New File' }
              Cmdk::Item(value: 'New Window') { '🪟 New Window' }
              Cmdk::Item(value: 'Search Docs') { '🔍 Search Docs' }
            end
          end
        end
      end
    end
  end

  class ScopedSearch < Phlex::HTML
    def view_template
      div(class: 'flex w-160 max-w-full flex-col gap-3') do
        div(class: 'flex flex-wrap items-center gap-x-2 gap-y-1 text-xs demo-hint') do
          plain 'Type'
          code(class: 'demo-chip') { '/' }
          plain 'to pick a scope, Enter to pin it as a pill, Backspace on empty input to leave. '
          plain 'Typing it out ('
          code(class: 'demo-chip') { '/user ' }
          plain ') works too.'
        end

        Cmdk::Root(label: 'Scoped search', scopes: %w[user doc], class: 'cmdk-vercel w-full') do
          div(class: 'cmdk-search-row') do
            Cmdk::Input(placeholder: "Search, or type '/' for scopes…")
          end
          Cmdk::List() do
            Cmdk::Empty() { 'No results found.' }
            Cmdk::Group(heading: 'Jump to') do
              Cmdk::Item(value: 'user', enters_scope: 'user', keywords: %w[people members]) { '🧑 Search users…' }
              Cmdk::Item(value: 'doc', enters_scope: 'doc', keywords: %w[files pages]) { '📄 Search documents…' }
            end
            Cmdk::Group(heading: 'Actions') do
              Cmdk::Item() { '➕ New Issue' }
              Cmdk::Item() { '🔍 Search Everything' }
            end
            Cmdk::Group(heading: 'Users', scope: 'user', scope_only: true) do
              Cmdk::Item() { '🧑 Leon Gieser' }
              Cmdk::Item() { '🧑 Anna Schmidt' }
              Cmdk::Item() { '🧑 Marc Weber' }
            end
            Cmdk::Group(heading: 'Documents', scope: 'doc') do
              Cmdk::Item() { '📄 README' }
              Cmdk::Item() { '📄 Architecture Notes' }
            end
          end
        end

        script { raw safe(<<~JS) }
          document.addEventListener('cmdk-scope-change', (e) => {
            // In a real app this is where you would kick off a server-backed
            // search, e.g. frame.src = `/search/users?q=${e.detail.query}`
            console.log('cmdk-scope-change', e.detail)
          })
        JS
      end
    end
  end

  # One menu rendered under different theme classes, with a footer whose hint
  # follows the selected item (Cmdk::Item hint:/kbd: → [cmdk-footer-hint]).
  class Themed < Phlex::HTML
    def initialize(theme:)
      @theme = theme
    end

    def view_template
      Cmdk::Root(label: 'Command Menu', loop: true, class: "#{@theme} w-160 max-w-full") do
        Cmdk::Input(placeholder: 'Search for apps and commands...')
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }

          Cmdk::Group(heading: 'Suggestions') do
            Cmdk::Item(value: 'Linear', hint: 'Open Application', kbd: '↵') do
              item('📐', 'Linear')
            end
            Cmdk::Item(value: 'Figma', hint: 'Open in New Tab', kbd: '⌘ ↵') do
              item('🎨', 'Figma')
              span(class: 'cmdk-raycast-meta ml-auto text-xs text-neutral-400') { 'Application' }
            end
            Cmdk::Item(value: 'Slack', hint: 'Open Application', kbd: '↵') do
              item('💬', 'Slack')
            end
          end

          Cmdk::Separator()

          Cmdk::Group(heading: 'Commands') do
            Cmdk::Item(value: 'Clipboard History', hint: 'Paste Latest', kbd: '⌘ V') do
              item('📋', 'Clipboard History')
            end
            Cmdk::Item(value: 'Search Emoji', hint: 'Insert Emoji', kbd: '↵') do
              item('😀', 'Search Emoji')
            end
            Cmdk::Item(value: 'Calculator') { item('🧮', 'Calculator (no hint)') }
          end
        end

        Cmdk::Footer() do
          span(aria_hidden: 'true') { '🚀' }
          div('cmdk-footer-hint' => '')
        end
      end
    end

    private

    def item(icon, text)
      span(class: 'text-base', aria_hidden: 'true') { icon }
      span { text }
    end
  end

  # A fully custom look: plain CSS against the [cmdk-*] attribute contract.
  # See the cmdk-terminal block in demo/assets/application.css.
  class CustomTheme < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Terminal', loop: true, class: 'cmdk-terminal w-160 max-w-full') do
        div(class: 'term-row') do
          span(class: 'term-prompt', aria_hidden: 'true') { '❯' }
          Cmdk::Input(placeholder: 'type a command_')
        end
        Cmdk::List() do
          Cmdk::Empty() { 'command not found' }
          Cmdk::Group(heading: 'processes') do
            Cmdk::Item(value: 'deploy production', hint: 'execute', kbd: '⏎') { plain 'bin/deploy --production' }
            Cmdk::Item(value: 'tail logs', hint: 'execute', kbd: '⏎') { plain 'tail -f log/production.log' }
            Cmdk::Item(value: 'rails console', hint: 'execute', kbd: '⏎') { plain 'bin/rails console' }
            Cmdk::Item(value: 'run tests', hint: 'execute', kbd: '⏎') { plain 'bundle exec rake test' }
          end
          Cmdk::Separator()
          Cmdk::Group(heading: 'danger zone') do
            Cmdk::Item(value: 'drop database', disabled: true) { plain 'bin/rails db:drop' }
          end
        end
        Cmdk::Footer() do
          span { 'guest@phlex-cmdk' }
          div('cmdk-footer-hint' => '')
        end
      end
    end
  end

  # A second fully custom look, this time with no stylesheet at all:
  # neo-brutalism via Tailwind utilities and data-[...] variants on the
  # components. Gotcha: inside Ruby heredocs Tailwind's scanner treats '#'
  # as a comment and drops the rest of the line, so colors avoid hex.
  class TailwindTheme < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Brutal Menu', loop: true, class: <<~CLASSES.split.join(' ')) do
        w-160 max-w-full border-4 border-black bg-amber-50 p-3
        shadow-[10px_10px_0_rgb(0,0,0)]
      CLASSES
        Cmdk::Input(placeholder: 'TYPE SOMETHING LOUD', class: <<~CLASSES.split.join(' '))
          w-full border-4 border-black bg-white px-3 py-2 text-base font-extrabold uppercase
          tracking-wide text-black outline-none placeholder:text-neutral-400
          focus:bg-yellow-200 focus:shadow-[4px_4px_0_rgb(0,0,0)]
        CLASSES
        Cmdk::List(class: 'h-[min(360px,calc(var(--cmdk-list-height)+16px))] max-h-[360px] overflow-y-auto overscroll-contain pt-3 pb-1 transition-[height] duration-100') do
          Cmdk::Empty(class: 'mx-1 flex h-16 items-center justify-center border-4 border-dashed border-black text-sm font-black uppercase text-black') do
            plain 'absolutely nothing'
          end
          Cmdk::Group(heading: 'loud actions', class: group_classes) do
            Cmdk::Item(value: 'Ship It', hint: 'No Regrets', kbd: '↵', class: item_classes) { entry('🚢', 'Ship It') }
            Cmdk::Item(value: 'Make It Pop', hint: 'More Contrast', kbd: '↵', class: item_classes) { entry('🎨', 'Make It Pop') }
            Cmdk::Item(value: 'Big Red Button', hint: 'Press It', kbd: '↵', class: item_classes) { entry('🔴', 'Big Red Button') }
          end
          Cmdk::Separator(class: 'mx-1 my-3 h-1 bg-black')
          Cmdk::Group(heading: 'regrets', class: group_classes) do
            Cmdk::Item(value: 'Undo Everything', disabled: true, class: item_classes) { entry('↩️', 'Undo Everything') }
          end
        end
        Cmdk::Footer(class: '-m-3 mt-3 flex items-center gap-2 border-t-4 border-black bg-fuchsia-300 px-4 py-2 text-xs font-black uppercase text-black') do
          span { 'brutal.exe' }
          div('cmdk-footer-hint' => '', class: <<~CLASSES.split.join(' '))
            ml-auto flex items-center gap-2 data-empty:hidden
            [&_kbd]:border-2 [&_kbd]:border-black [&_kbd]:bg-white [&_kbd]:px-1.5
            [&_kbd]:shadow-[2px_2px_0_rgb(0,0,0)]
          CLASSES
        end
      end
    end

    private

    def group_classes
      <<~CLASSES.split.join(' ')
        [&_[cmdk-group-heading]]:m-2 [&_[cmdk-group-heading]]:inline-block
        [&_[cmdk-group-heading]]:-rotate-2 [&_[cmdk-group-heading]]:bg-black
        [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-0.5
        [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-black
        [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-widest
        [&_[cmdk-group-heading]]:text-amber-50
      CLASSES
    end

    def item_classes
      <<~CLASSES.split.join(' ')
        mx-1 mb-2 flex min-h-11 cursor-pointer items-center gap-2 border-2 border-black bg-white
        px-3 text-sm font-bold text-black select-none shadow-[4px_4px_0_rgb(0,0,0)]
        transition-[transform,box-shadow,background-color] duration-75
        data-[selected=true]:translate-x-[2px] data-[selected=true]:translate-y-[2px]
        data-[selected=true]:bg-yellow-300 data-[selected=true]:shadow-[2px_2px_0_rgb(0,0,0)]
        data-[disabled=true]:cursor-not-allowed data-[disabled=true]:bg-neutral-200
        data-[disabled=true]:text-neutral-500 data-[disabled=true]:shadow-none
        data-[disabled=true]:line-through
      CLASSES
    end

    def entry(icon, text)
      span(class: 'text-base', aria_hidden: 'true') { icon }
      span { text }
    end
  end

  class Events < Phlex::HTML
    def view_template
      div(class: 'flex w-160 max-w-full flex-col gap-4') do
        render Menu.new
        pre(id: 'event-log',
            class: 'demo-panel h-32 overflow-y-auto p-3 text-xs')
        script { raw safe(<<~JS) }
          const log = document.getElementById('event-log')
          for (const type of ['cmdk-item-select', 'cmdk-value-change', 'cmdk-search-change']) {
            document.addEventListener(type, (e) => {
              log.textContent = `${type.padEnd(18)} ${JSON.stringify(e.detail)}\\n` + log.textContent
            })
          }
        JS
      end
    end
  end
end
