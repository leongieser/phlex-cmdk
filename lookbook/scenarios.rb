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
                 class: 'cmdk-vercel w-[28rem] max-w-full') do
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
      Cmdk::Root(label: 'Fruits', class: 'cmdk-vercel w-[28rem] max-w-full') do
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
      Cmdk::Root(label: 'Force mount', class: 'cmdk-vercel w-[28rem] max-w-full') do
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
      Cmdk::Root(label: 'Loading', class: 'cmdk-vercel w-[28rem] max-w-full') do
        Cmdk::Input(placeholder: 'Fetching results...')
        Cmdk::List() do
          Cmdk::Loading(progress: @progress) { 'Hang on, loading results…' }
        end
      end
    end
  end

  class Empty < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Empty', class: 'cmdk-vercel w-[28rem] max-w-full') do
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
                     class: 'cmdk-vercel w-[36rem] max-w-full') do
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
      div(class: 'flex w-[28rem] max-w-full flex-col gap-3') do
        div(class: 'flex flex-wrap items-center gap-x-2 gap-y-1 text-xs demo-hint') do
          plain 'Type'
          code(class: 'demo-chip') { '/' }
          plain 'to pick a scope, Enter to pin it as a pill, Backspace on empty input to leave.'
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
      Cmdk::Root(label: 'Command Menu', loop: true, class: "#{@theme} w-[40rem] max-w-full") do
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
      Cmdk::Root(label: 'Terminal', loop: true, class: 'cmdk-terminal w-[40rem] max-w-full') do
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

  # The same terminal look, but with no stylesheet at all: Tailwind utilities
  # and data-[...] variants directly on the components.
  # Gotcha: inside Ruby heredocs Tailwind's scanner treats '#' as a comment
  # and drops the rest of the line, so hex colors are written as rgb().
  class TailwindTheme < Phlex::HTML
    def view_template
      Cmdk::Root(label: 'Terminal (Tailwind)', loop: true, class: <<~CLASSES.split.join(' ')) do
        w-[40rem] max-w-full relative overflow-hidden rounded-md border border-green-900
        bg-[rgb(4,16,10)] p-2 font-mono text-green-400
        shadow-[0_0_50px_rgba(74,222,128,0.18),inset_0_0_90px_rgba(74,222,128,0.05)]
        after:pointer-events-none after:absolute after:inset-0 after:content-['']
        after:bg-[repeating-linear-gradient(0deg,rgba(0,0,0,0.22)_0_1px,transparent_1px_3px)]
      CLASSES
        div(class: 'flex items-center gap-2.5 border-b border-dashed border-green-900 px-2 pt-1') do
          span(class: 'animate-pulse text-green-400', aria_hidden: 'true') { '❯' }
          Cmdk::Input(placeholder: 'type a command_', class: <<~CLASSES.split.join(' '))
            flex-1 border-none bg-transparent pt-2 pb-3 font-mono text-sm tracking-wide
            text-green-200 caret-green-400 outline-none placeholder:text-green-400/35
          CLASSES
        end
        Cmdk::List(class: 'h-[min(330px,var(--cmdk-list-height))] max-h-[330px] overflow-y-auto overscroll-contain pt-1.5 transition-[height] duration-100') do
          Cmdk::Empty(class: "flex h-14 items-center justify-center text-[13px] text-green-400/45 before:content-['sh:_']") do
            plain 'command not found'
          end
          Cmdk::Group(heading: 'processes',
                      class: '[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:pt-3 [&_[cmdk-group-heading]]:pb-1 ' \
                             '[&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:uppercase ' \
                             "[&_[cmdk-group-heading]]:tracking-[0.25em] [&_[cmdk-group-heading]]:text-green-400/50 [&_[cmdk-group-heading]]:before:content-['#_']") do
            Cmdk::Item(value: 'deploy production', hint: 'execute', kbd: '⏎', class: item_classes) { plain 'bin/deploy --production' }
            Cmdk::Item(value: 'tail logs', hint: 'execute', kbd: '⏎', class: item_classes) { plain 'tail -f log/production.log' }
            Cmdk::Item(value: 'rails console', hint: 'execute', kbd: '⏎', class: item_classes) { plain 'bin/rails console' }
          end
          Cmdk::Separator(class: 'mx-2 my-2 border-t border-dashed border-green-900')
          Cmdk::Group(heading: 'danger zone',
                      class: '[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:pt-3 [&_[cmdk-group-heading]]:pb-1 ' \
                             '[&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:uppercase ' \
                             "[&_[cmdk-group-heading]]:tracking-[0.25em] [&_[cmdk-group-heading]]:text-green-400/50 [&_[cmdk-group-heading]]:before:content-['#_']") do
            Cmdk::Item(value: 'drop database', disabled: true, class: item_classes) { plain 'bin/rails db:drop' }
          end
        end
        Cmdk::Footer(class: '-m-2 mt-1.5 flex items-center gap-2 border-t border-dashed border-green-900 px-4 py-2 text-xs text-green-400/55') do
          span { 'guest@phlex-cmdk' }
          div('cmdk-footer-hint' => '', class: <<~CLASSES.split.join(' '))
            ml-auto flex items-center gap-1.5 text-green-300 data-empty:hidden
            [&_kbd]:rounded-[3px] [&_kbd]:border [&_kbd]:border-green-900 [&_kbd]:bg-green-400/10
            [&_kbd]:px-1.5 [&_kbd]:text-[11px] [&_kbd]:text-green-400
          CLASSES
        end
      end
    end

    private

    def item_classes
      <<~CLASSES.split.join(' ')
        flex min-h-8 cursor-pointer items-center gap-2 px-2 text-sm text-green-300 select-none
        before:whitespace-pre before:text-green-400 before:content-['__']
        data-[selected=true]:bg-green-400/15 data-[selected=true]:text-green-100
        data-[selected=true]:before:content-['❯_']
        data-[selected=true]:[text-shadow:0_0_10px_rgba(74,222,128,0.55)]
        data-[disabled=true]:text-green-400/30 data-[disabled=true]:line-through data-[disabled=true]:cursor-not-allowed
      CLASSES
    end
  end

  class Events < Phlex::HTML
    def view_template
      div(class: 'flex w-[28rem] max-w-full flex-col gap-4') do
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
