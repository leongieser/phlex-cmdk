require 'rack'
require_relative '../lib/cmdk'

module Views
  class Layout < Phlex::HTML
    def initialize(title: 'phlex-cmdk')
      @title = title
    end

    def view_template(&block)
      doctype
      html(lang: 'en') do
        head do
          meta(charset: 'utf-8')
          meta(name: 'viewport', content: 'width=device-width, initial-scale=1')
          title { @title }
          link(rel: 'stylesheet', href: '/application.css')
          script(type: 'module', src: 'https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.13/+esm')
          script(type: 'module', src: '/cmdk.js')
        end
        body(class: 'cmdk-canvas min-h-screen antialiased') do
          yield_content(&block)
        end
      end
    end

    private

    def yield_content(&block)
      block ? block.call : nil
    end
  end

  class Home < Phlex::HTML
    def view_template
      render Layout.new do
        main(class: 'mx-auto flex max-w-2xl flex-col items-center gap-8 px-4 py-16') do
          header(class: 'text-center') do
            h1(class: 'text-3xl font-semibold tracking-tight') { '⌘K for Phlex' }
            p(class: 'demo-hint mt-2 text-sm') do
              plain 'A Phlex + vanilla JS port of '
              a(href: 'https://cmdk.paco.me', class: 'underline') { 'cmdk' }
              plain ' — press '
              kbd(class: 'demo-chip px-1.5 py-0.5 font-sans text-xs') { '⌘K' }
              plain ' for the dialog version.'
            end
          end

          command_menu

          section(class: 'w-full max-w-xl') do
            h2(class: 'mb-2 text-xs font-medium uppercase tracking-wide text-neutral-400') { 'Events' }
            pre(id: 'event-log', class: 'demo-panel h-28 overflow-y-auto p-3 text-xs')
          end

          command_dialog
        end

        script { raw safe(<<~JS) }
          const log = (msg) => {
            const el = document.getElementById('event-log')
            el.textContent = `${msg}\\n` + el.textContent
          }
          document.addEventListener('cmdk-item-select', (e) => log(`cmdk-item-select  ${e.detail.value}`))
          document.addEventListener('cmdk-value-change', (e) => log(`cmdk-value-change ${e.detail.value}`))
        JS
      end
    end

    private

    def command_menu
      Cmdk::Root(label: 'Global Command Menu', loop: true, class: 'cmdk-vercel w-full max-w-xl') do
        Cmdk::Input(placeholder: 'What do you need?')
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }

          Cmdk::Group(heading: 'Suggestions') do
            menu_items
          end

          Cmdk::Separator()

          Cmdk::Group(heading: 'Settings') do
            Cmdk::Item(value: 'Change Theme', keywords: %w[appearance theme]) { item_label('🌗', 'Change Theme') }
            Cmdk::Item(value: 'Edit Profile', href: '/profile') { item_label('🧑', 'Edit Profile (visits /profile)') }
            Cmdk::Item(value: 'Admin Settings', disabled: true) { item_label('🔒', 'Admin Settings (disabled)') }
          end
        end
      end
    end

    def command_dialog
      Cmdk::Dialog(label: 'Command Menu', hotkey: 'k', loop: true,
                   dialog_attributes: { class: 'cmdk-dialog-frame' }, class: 'cmdk-vercel w-[36rem] max-w-full') do
        Cmdk::Input(placeholder: 'Type a command or search...')
        Cmdk::List() do
          Cmdk::Empty() { 'No results found.' }
          Cmdk::Group(heading: 'Suggestions') { menu_items }
        end
      end
    end

    def menu_items
      Cmdk::Item(value: 'Linear', keywords: %w[issue tracker]) { item_label('📐', 'Linear') }
      Cmdk::Item(value: 'Figma', keywords: %w[design]) { item_label('🎨', 'Figma') }
      Cmdk::Item(value: 'Slack', keywords: %w[chat team]) { item_label('💬', 'Slack') }
      Cmdk::Item(value: 'YouTube', keywords: %w[video]) { item_label('📺', 'YouTube') }
      Cmdk::Item(value: 'Raycast', keywords: %w[launcher]) { item_label('🚀', 'Raycast') }
    end

    def item_label(icon, text)
      span(class: 'text-base', aria_hidden: 'true') { icon }
      span { text }
    end
  end
end

class DemoApp
  def call(env)
    request = Rack::Request.new(env)

    case request.path_info
    when '/'
      html Views::Home.new.call
    when '/profile'
      html profile_page
    when '/cmdk.js'
      file Cmdk.javascript_path, 'text/javascript'
    when '/application.css'
      file File.expand_path('public/application.css', __dir__), 'text/css'
    else
      [404, { 'content-type' => 'text/plain' }, ['Not found']]
    end
  end

  private

  def profile_page
    Class.new(Phlex::HTML) do
      def view_template
        render Views::Layout.new(title: 'Profile') do
          main(class: 'mx-auto max-w-2xl px-4 py-16') do
            h1(class: 'text-2xl font-semibold') { 'Profile' }
            p(class: 'mt-2 text-neutral-500') { 'You navigated here by selecting a cmdk item with href.' }
            a(href: '/', class: 'mt-4 inline-block underline') { 'Back' }
          end
        end
      end
    end.new.call
  end

  def html(content)
    [200, { 'content-type' => 'text/html; charset=utf-8' }, [content]]
  end

  def file(path, content_type)
    return [404, { 'content-type' => 'text/plain' }, ['Not found']] unless File.exist?(path)

    [200, { 'content-type' => content_type, 'cache-control' => 'no-cache' }, [File.read(path)]]
  end
end
