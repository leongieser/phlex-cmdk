# Static site generator for GitHub Pages: pre-renders the Lookbook scenarios
# with Phlex into plain HTML. The runtime is client-side JS and the themes are
# plain CSS, so everything stays fully interactive without a server (the only
# exception: server-backed scope search, which needs an app).
#
#   bundle exec rake site   # builds into _site/

require 'fileutils'
require 'json'
require 'kramdown'
require 'kramdown-parser-gfm'
require_relative '../lib/cmdk'
require_relative '../lookbook/scenarios'

ROOT = File.expand_path('..', __dir__)
SITE = File.join(ROOT, '_site')

# Icon-only copy button contents: the copy glyph (two cards that spring apart on
# hover) and a check (drawn in via stroke-dashoffset) shown after copying. Ported
# from the animated lucide icons; the motion springs become CSS transitions.
COPY_ICON_HTML = <<~SVG.freeze
  <svg class="copy-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect class="copy-front" x="8" y="8" width="14" height="14" rx="2" ry="2"/><path class="copy-back" d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg><svg class="check-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path class="check-path" pathLength="1" d="M4 12 9 17L20 6"/></svg>
SVG

# shadcn-style mode toggle: the trigger shows sun or moon for the resolved
# appearance (no System glyph); the menu offers Light / Dark / System. Rendered
# in the header and again beside the theme builder; one shared script wires
# every instance and keeps their active state in sync.
class AppearanceToggle < Phlex::HTML
  SUN_ICON = '<svg class="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>'
  MOON_ICON = '<svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>'

  def view_template
    div(class: 'theme-menu', data: { theme_menu: '' }) do
      button(type: 'button', class: 'theme-menu-trigger', data: { theme_trigger: '' },
             aria_haspopup: 'menu', aria_expanded: 'false', aria_label: 'Toggle color mode') do
        raw safe(SUN_ICON)
        raw safe(MOON_ICON)
      end
      div(class: 'theme-menu-list', role: 'menu', hidden: true) do
        %w[light dark system].each do |mode|
          button(type: 'button', role: 'menuitem', class: 'theme-menu-item',
                 data: { set_appearance: mode }) { mode.capitalize }
        end
      end
    end
  end
end

class SitePage < Phlex::HTML
  GITHUB_ICON = '<svg viewBox="0 0 14 14" fill="currentColor" aria-hidden="true"><path d="M7 .175C3.128.175 0 3.303 0 7.175c0 3.084 2.013 5.71 4.79 6.65.35.066.482-.153.482-.328v-1.181c-1.947.415-2.363-.941-2.363-.941-.328-.81-.787-1.028-.787-1.028-.634-.438.044-.416.044-.416.7.044 1.071.722 1.071.722.635 1.072 1.641.766 2.035.59.066-.459.24-.765.437-.94-1.553-.175-3.193-.787-3.193-3.456 0-.766.262-1.378.721-1.881-.065-.175-.306-.897.066-1.86 0 0 .59-.197 1.925.722A6.7 6.7 0 0 1 6.978 3.588c.59 0 1.203.087 1.75.24 1.335-.897 1.925-.722 1.925-.722.372.963.131 1.685.066 1.86.46.48.722 1.115.722 1.88 0 2.691-1.641 3.282-3.194 3.457.24.219.481.634.481 1.29v1.926c0 .197.131.415.481.328C11.988 12.884 14 10.259 14 7.175 14 3.303 10.872.175 7 .175Z"/></svg>'
  # lucide "gem" — stroked to sit alongside the sun/moon toggle.
  RUBYGEMS_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3h12l4 6-10 13L2 9Z"/><path d="M11 3 8 9l4 13 4-13-3-6"/><path d="M2 9h20"/></svg>'

  # Set the stored mode and its resolved light/dark before first paint, so the
  # page never flashes the wrong appearance on load or navigation.
  THEME_BOOT_JS = <<~JS
    (function () {
      try {
        var mode = localStorage.getItem('phlex-cmdk-theme') || 'system'
        var dark = mode === 'dark' || (mode === 'system' && matchMedia('(prefers-color-scheme: dark)').matches)
        document.documentElement.dataset.theme = mode
        document.documentElement.dataset.resolvedTheme = dark ? 'dark' : 'light'
      } catch (e) {}
    })()
  JS

  def initialize(title:, current:)
    @title = title
    @current = current
  end

  def view_template(&block)
    doctype
    html(lang: 'en') do
      head do
        meta(charset: 'utf-8')
        meta(name: 'viewport', content: 'width=device-width, initial-scale=1')
        title { @title }
        meta(name: 'description', content: 'phlex-cmdk: fast, composable command menu for Phlex. A Ruby port of cmdk.')
        script { raw safe(THEME_BOOT_JS) }
        link(rel: 'stylesheet', href: './site.css')
        # Resolve the runtime and the optional Stimulus base controller as bare
        # specifiers (the examples page registers a controller that imports them).
        script(type: 'importmap') do
          raw safe(JSON.generate(imports: {
            'cmdk' => './cmdk.js',
            'cmdk_controller' => './cmdk_controller.js',
            '@hotwired/stimulus' => 'https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/+esm',
          }))
        end
        script(type: 'module', src: './cmdk.js')
        script(src: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js', defer: true)
      end
      body(class: 'cmdk-canvas flex min-h-screen flex-col antialiased') do
        div(class: 'site-bg', aria_hidden: 'true')
        div(class: 'site-header') do
          header(class: 'mx-auto flex w-full max-w-5xl items-center gap-4 px-4 py-4 text-sm sm:gap-5 sm:px-6') do
            a(href: './', class: 'shrink-0 font-semibold tracking-tight whitespace-nowrap') { '⌘K phlex-cmdk' }
            nav(class: 'demo-hint hidden gap-4 sm:flex') do
              nav_link('Playground', './')
              nav_link('Examples', './examples.html')
              nav_link('Styling', './styling.html')
              nav_link('Docs', './docs.html')
            end
            div(class: 'ml-auto flex items-center gap-1') do
              a(href: 'https://rubygems.org/gems/phlex-cmdk', class: 'header-icon-link',
                aria_label: 'RubyGems page', title: 'RubyGems') { raw safe(RUBYGEMS_ICON) }
              a(href: 'https://github.com/leongieser/phlex-cmdk', class: 'header-icon-link',
                aria_label: 'GitHub repository', title: 'GitHub') { raw safe(GITHUB_ICON) }
              render AppearanceToggle.new
            end
          end
        end
        block&.call
        script { raw safe(<<~JS) }
          // The shortcut is Cmd+K on macOS, Ctrl+K everywhere else (the runtime
          // accepts both), so show the right modifier on the keycap hint.
          if (!/Mac|iPhone|iPad|iPod/.test(navigator.platform || navigator.userAgent)) {
            document.querySelectorAll('[data-cmd-key]').forEach((el) => { el.textContent = 'Ctrl' })
          }

          // Frost the header only once scrolled, so the top of the page keeps
          // its transparent background pattern.
          const siteHeader = document.querySelector('.site-header')
          if (siteHeader) {
            const onScroll = () => siteHeader.classList.toggle('is-scrolled', window.scrollY > 4)
            addEventListener('scroll', onScroll, { passive: true })
            onScroll()
          }

          // Freeze each example's initial height so filtering (which shrinks
          // the list) does not shift the layout below it.
          addEventListener('load', () => {
            document.querySelectorAll('[data-freeze-height]').forEach((el) => {
              el.style.minHeight = `${el.offsetHeight}px`
            })
          })

          addEventListener('load', () => {
            if (window.hljs) document.querySelectorAll('pre code[class*="language-"]').forEach((el) => hljs.highlightElement(el))
          })

          // Copy buttons for code blocks (the install command, docs snippets).
          // The theme builder's output updates live and has its own copy button.
          // Copy with a fallback: the async clipboard API can reject (blocked
          // permission, unfocused/embedded context) even where it exists, so
          // fall back to a hidden textarea + execCommand.
          window.copyText = async (text) => {
            try { await navigator.clipboard.writeText(text); return true } catch (e) {}
            try {
              const ta = document.createElement('textarea')
              ta.value = text
              ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0'
              document.body.appendChild(ta)
              ta.focus()
              ta.select()
              const ok = document.execCommand('copy')
              ta.remove()
              return ok
            } catch (e) { return false }
          }
          const copyIconHTML = #{COPY_ICON_HTML.to_json}
          document.querySelectorAll('pre:not(.builder-output)').forEach((pre) => {
            const text = pre.textContent.trim()
            if (!text) return
            const button = document.createElement('button')
            button.type = 'button'
            button.className = 'copy-button'
            button.innerHTML = copyIconHTML
            button.setAttribute('aria-label', 'Copy to clipboard')
            button.addEventListener('click', () => {
              window.copyText(text)
              button.classList.add('copied')
              clearTimeout(button._copyTimer)
              button._copyTimer = setTimeout(() => button.classList.remove('copied'), 2000)
            })
            pre.classList.add('has-copy')
            pre.appendChild(button)
          })

          // Appearance (light / dark / system): one shared setter that the
          // header dropdown and the command menu's Mode group both call.
          const THEME_KEY = 'phlex-cmdk-theme'
          const prefersDark = matchMedia('(prefers-color-scheme: dark)')
          const resolve = (mode) => (mode === 'dark' || (mode === 'system' && prefersDark.matches) ? 'dark' : 'light')
          window.setAppearance = (mode) => {
            document.documentElement.dataset.theme = mode
            document.documentElement.dataset.resolvedTheme = resolve(mode)
            try { localStorage.setItem(THEME_KEY, mode) } catch (e) {}
            document.querySelectorAll('[data-set-appearance]').forEach((el) => {
              el.setAttribute('aria-current', String(el.dataset.setAppearance === mode))
            })
          }
          window.setAppearance(localStorage.getItem(THEME_KEY) || document.documentElement.dataset.theme || 'system')
          prefersDark.addEventListener('change', () => {
            if ((localStorage.getItem(THEME_KEY) || 'system') === 'system') {
              document.documentElement.dataset.resolvedTheme = resolve('system')
            }
          })

          // Wire every appearance dropdown (header + the one by the builder);
          // window.setAppearance already syncs the active state across all of them.
          document.querySelectorAll('[data-theme-menu]').forEach((themeMenu) => {
            const trigger = themeMenu.querySelector('[data-theme-trigger]')
            const list = themeMenu.querySelector('[role="menu"]')
            const close = () => { list.hidden = true; trigger.setAttribute('aria-expanded', 'false') }
            trigger.addEventListener('click', (e) => {
              e.stopPropagation()
              const open = list.hidden
              list.hidden = !open
              trigger.setAttribute('aria-expanded', String(open))
            })
            themeMenu.querySelectorAll('[data-set-appearance]').forEach((item) => {
              item.addEventListener('click', () => { window.setAppearance(item.dataset.setAppearance); close() })
            })
            document.addEventListener('click', (e) => { if (!themeMenu.contains(e.target)) close() })
            document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close() })
          })
        JS
        footer(class: 'demo-hint mt-auto w-full px-4 py-8 text-center text-xs') do
          plain 'MIT · a Phlex port of '
          a(href: 'https://cmdk.paco.me', class: 'underline') { 'cmdk' }
          plain ' by Paco Coursey'
        end
      end
    end
  end

  private

  def nav_link(label, href)
    active = @current == label
    a(href: href, class: active ? 'font-medium text-current' : 'hover:underline') { label }
  end
end

class PlaygroundPage < Phlex::HTML
  SEARCH_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' \
                'stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/>' \
                '<path d="m21 21-4.3-4.3"/></svg>'

  # Theme pill marks. Vercel/Linear/Raycast are the official logos from the
  # cmdk website (Vercel uses currentColor so it adapts to light/dark);
  # Terminal and Brutalism are our own themes, so they get matching glyphs.
  VERCEL_MARK = '<svg viewBox="0 0 75 65" fill="currentColor" aria-hidden="true"><path d="M37.59.25l36.95 64H.64l36.95-64z"/></svg>'
  LINEAR_MARK = '<svg viewBox="0 0 64 64" fill="#5E6AD2" aria-hidden="true"><path d="M.403 37.4 26.6 63.597C13.223 61.336 2.664 50.777.403 37.4Z"/><path d="M0 30.287 33.713 64c2.005-.107 3.961-.399 5.852-.858L.858 24.436A31.6 31.6 0 0 0 0 30.287Z"/><path d="M2.536 19.404 44.596 61.464a31.7 31.7 0 0 0 4.4-2.31L4.845 15.005a31.7 31.7 0 0 0-2.31 4.4Z"/><path d="M7.695 11.145C13.568 4.321 22.268 0 31.977 0 49.663 0 64 14.337 64 32.023c0 9.71-4.321 18.41-11.145 24.282L7.695 11.145Z"/></svg>'
  RAYCAST_MARK = '<svg viewBox="0 0 28 28" fill="#FF6363" aria-hidden="true"><path fill-rule="evenodd" clip-rule="evenodd" d="M7 18.073V20.994L0 13.994l1.46-1.46L7 18.075v-.002Zm2.921 2.921H7l7 7 1.46-1.46-5.539-5.54Zm16.614-5.538 1.461-1.462L13.996-.006l-1.458 1.466 5.539 5.538H14.73l-3.866-3.858-1.46 1.46 2.405 2.404h-1.68V17.87h10.865v-1.68l2.405 2.404 1.46-1.46-3.865-3.866V9.921l5.54 5.535ZM7.73 6.27 6.265 7.732l1.568 1.566 1.461-1.46L7.73 6.27Zm12.432 12.432-1.46 1.462 1.566 1.568 1.462-1.462-1.568-1.568ZM4.596 9.404l-1.462 1.462L7 14.732v-2.923L4.596 9.404ZM16.192 21h-2.924l3.866 3.866 1.462-1.462L16.192 21Z"/></svg>'
  TERMINAL_MARK = '<svg viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="5 8 9 12 5 16"/><line x1="12" y1="16" x2="18" y2="16"/></svg>'
  BRUTAL_MARK = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="3.5" width="17" height="17" fill="#fde047" stroke="#000" stroke-width="2.5"/></svg>'

  def view_template
    render SitePage.new(title: 'phlex-cmdk: command menu for Phlex', current: 'Playground') do
      main(class: 'mx-auto flex w-full max-w-4xl flex-1 flex-col items-center justify-center gap-8 px-4 py-16') do
        section(class: 'flex flex-col items-center text-center') do
          h1(class: 'text-5xl font-semibold tracking-tight') { 'Phlex ⌘K' }
          p(class: 'demo-hint mx-auto mt-4 max-w-md text-sm leading-relaxed') do
            plain 'A fast, composable command menu for Ruby, ported from '
            a(href: 'https://cmdk.paco.me', class: 'underline') { 'cmdk' }
            # plain ' with full feature parity.'
          end
        end

        # The hero action: a faux command bar that previews the real input and
        # opens the palette on click. Its placeholder types out things to try.
        section(class: 'flex w-full flex-col items-center gap-5') do
          button(id: 'open-palette', type: 'button', aria_label: 'Open command menu', class: 'hero-trigger') do
            span(class: 'hero-trigger-icon', aria_hidden: 'true') { raw safe(SEARCH_ICON) }
            span(class: 'hero-trigger-text') do
              span(id: 'hero-placeholder') { 'Search for apps and commands' }
              span(class: 'hero-caret', aria_hidden: 'true')
            end
            span(class: 'flex shrink-0 gap-1') do
              kbd(class: 'demo-kbd', data: { cmd_key: '' }) { '⌘' }
              kbd(class: 'demo-kbd') { 'K' }
            end
          end

          div(class: 'flex flex-wrap items-center justify-center gap-2') do
            theme_pill('Vercel', 'cmdk-vercel', VERCEL_MARK, checked: true)
            theme_pill('Linear', 'cmdk-linear', LINEAR_MARK)
            theme_pill('Raycast', 'cmdk-raycast', RAYCAST_MARK)
            theme_pill('Terminal', 'cmdk-terminal', TERMINAL_MARK)
            theme_pill('Brutalism', 'cmdk-brutal', BRUTAL_MARK)
          end

          pre(class: 'demo-panel w-fit px-4 py-2 text-left text-xs') { 'gem install phlex-cmdk' }
        end

        command_dialog

        script(src: 'https://cdn.jsdelivr.net/npm/canvas-confetti@1.9.3/dist/confetti.browser.min.js')
        script { raw safe(<<~JS) }
          const dialog = document.querySelector('dialog[cmdk-dialog]')
          document.getElementById('open-palette').addEventListener('click', () => Cmdk.openDialog(dialog))

          // Type the faux placeholder through a few things worth trying.
          const placeholder = document.getElementById('hero-placeholder')
          const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches
          if (placeholder && !reduceMotion) {
            const phrases = [
              'Search for apps and commands',
              'Jump straight to the docs',
              'Switch to the Raycast theme',
              'Toggle dark mode',
              'Throw some confetti',
            ]
            let phrase = 0, chars = phrases[0].length, deleting = true
            const tick = () => {
              const word = phrases[phrase]
              placeholder.textContent = word.slice(0, chars)
              let delay = deleting ? 35 : 70
              if (!deleting && chars === word.length) { deleting = true; delay = 1800 }
              else if (deleting && chars === 0) { deleting = false; phrase = (phrase + 1) % phrases.length; delay = 250 }
              else chars += deleting ? -1 : 1
              setTimeout(tick, delay)
            }
            setTimeout(tick, 1800)
          }

          const setTheme = (themeClass) => {
            const root = dialog.querySelector('[cmdk-root]')
            root.classList.remove('cmdk-vercel', 'cmdk-linear', 'cmdk-raycast', 'cmdk-terminal', 'cmdk-brutal')
            root.classList.add(themeClass)
            const radio = document.querySelector(`[data-theme-choice="${themeClass}"]`)
            if (radio) radio.checked = true
          }
          const burstConfetti = () => {
            // The native <dialog> sits in the top layer, above any canvas, so
            // close the palette first and let it rain.
            dialog.close()
            confetti({ particleCount: 130, spread: 75, origin: { y: 0.6 } })
            confetti({ particleCount: 60, angle: 60, spread: 55, origin: { x: 0 } })
            confetti({ particleCount: 60, angle: 120, spread: 55, origin: { x: 1 } })
          }

          dialog.addEventListener('cmdk-item-select', (event) => {
            const item = event.target
            if (item.hasAttribute('data-confetti')) burstConfetti()
            else if (item.dataset.setTheme) setTheme(item.dataset.setTheme)
            else if (item.dataset.setAppearance) window.setAppearance(item.dataset.setAppearance)
          })

          document.querySelectorAll('[data-theme-choice]').forEach((el) => {
            el.addEventListener('change', () => {
              setTheme(el.dataset.themeChoice)
              Cmdk.openDialog(dialog)
            })
          })
        JS
      end
    end
  end

  private

  def command_dialog
    Cmdk::Dialog(label: 'Command Menu', hotkey: 'k', loop: true,
                 dialog_attributes: { class: 'cmdk-dialog-frame' },
                 class: 'cmdk-vercel w-160 max-w-full') do
      Cmdk::Input(placeholder: 'Search for apps, commands and pages...')
      Cmdk::List() do
        Cmdk::Empty() { 'No results found.' }

        Cmdk::Item(value: 'Confetti', hint: 'Celebrate', kbd: '↵', data: { confetti: '' }) { entry('🎉', 'Confetti') }

        Cmdk::Group(heading: 'Pages', force_mount: true) do
          # Playground is omitted: this landing page is the Playground route.
          Cmdk::Item(value: 'Examples', href: './examples.html', hint: 'Go to Page', kbd: '↵') { entry('🧪', 'Examples') }
          Cmdk::Item(value: 'Styling', href: './styling.html', hint: 'Go to Page', kbd: '↵') { entry('🎨', 'Styling') }
          Cmdk::Item(value: 'Docs', href: './docs.html', hint: 'Go to Page', kbd: '↵') { entry('📚', 'Docs') }
          Cmdk::Item(value: 'GitHub', href: 'https://github.com/leongieser/phlex-cmdk', hint: 'Open Repository', kbd: '↵') { entry('🐙', 'GitHub') }
        end

        Cmdk::Group(heading: 'Theme') do
          Cmdk::Item(value: 'Theme: Vercel', keywords: %w[theme], hint: 'Switch Theme', kbd: '↵',
                     data: { set_theme: 'cmdk-vercel' }) { entry('▲', 'Vercel') }
          Cmdk::Item(value: 'Theme: Linear', keywords: %w[theme], hint: 'Switch Theme', kbd: '↵',
                     data: { set_theme: 'cmdk-linear' }) { entry('📐', 'Linear') }
          Cmdk::Item(value: 'Theme: Raycast', keywords: %w[theme], hint: 'Switch Theme', kbd: '↵',
                     data: { set_theme: 'cmdk-raycast' }) { entry('🚀', 'Raycast') }
          Cmdk::Item(value: 'Theme: Terminal', keywords: %w[theme custom crt], hint: 'Switch Theme', kbd: '↵',
                     data: { set_theme: 'cmdk-terminal' }) { entry('💻', 'Terminal') }
          Cmdk::Item(value: 'Theme: Brutalism', keywords: %w[theme custom brutal], hint: 'Switch Theme', kbd: '↵',
                     data: { set_theme: 'cmdk-brutal' }) { entry('🧱', 'Brutalism') }
        end

        Cmdk::Group(heading: 'Mode') do
          Cmdk::Item(value: 'Mode: System', keywords: %w[mode appearance], hint: 'Switch Mode', kbd: '↵',
                     data: { set_appearance: 'system' }) { entry('🖥️', 'System') }
          Cmdk::Item(value: 'Mode: Light', keywords: %w[mode appearance], hint: 'Switch Mode', kbd: '↵',
                     data: { set_appearance: 'light' }) { entry('☀️', 'Light') }
          Cmdk::Item(value: 'Mode: Dark', keywords: %w[mode appearance], hint: 'Switch Mode', kbd: '↵',
                     data: { set_appearance: 'dark' }) { entry('🌙', 'Dark') }
        end
      end
      Cmdk::Footer() do
        span(aria_hidden: 'true') { '🚀' }
        div('cmdk-footer-hint' => '')
      end
    end
  end

  def entry(icon, text)
    span(class: 'text-base', aria_hidden: 'true') { icon }
    span { text }
  end

  def theme_pill(label, theme_class, mark, checked: false)
    label(class: 'theme-pill') do
      input(type: 'radio', name: 'theme', class: 'sr-only', checked: checked, data: { theme_choice: theme_class })
      span(class: 'theme-pill-mark') { raw safe(mark) }
      plain label
    end
  end

end

class ExamplesPage < Phlex::HTML
  SCENARIO_SRC = File.read(File.join(ROOT, 'lookbook/scenarios.rb'), encoding: 'UTF-8')
  THEME_CSS_SRC = File.read(File.join(ROOT, 'assets/css/cmdk_themes.css'), encoding: 'UTF-8')
  SITE_CSS_SRC = File.read(File.join(ROOT, 'demo/assets/application.css'), encoding: 'UTF-8')

  def self.scenario_source(name)
    SCENARIO_SRC.match(/^  class #{name} < Phlex::HTML\n.*?^  end$/m)[0].gsub(/^  /, '')
  end

  # Split a scenario into its view_template body (the composition, as you would
  # write it in a view) and its supporting methods (initialize + helpers).
  def self.method_blocks(name)
    lines = scenario_source(name).lines
    composition = []
    setup = []
    i = 0
    while i < lines.length
      if lines[i] =~ /^  def view_template/
        i += 1
        while lines[i] !~ /^  end$/
          composition << lines[i].sub(/^    /, '')
          i += 1
        end
      elsif lines[i] =~ /^  def /
        while lines[i] !~ /^  end$/
          setup << lines[i].sub(/^  /, '')
          i += 1
        end
        setup << "end\n"
      end
      i += 1
    end
    [composition.join.rstrip, setup.join.rstrip]
  end

  # Ruby panes for an example: the composition, plus a Setup pane when the
  # scenario has supporting methods. `code:` overrides the first pane's icon.
  def self.ruby_panes(name, code: :code)
    composition, setup = method_blocks(name)
    panes = [[code, 'ruby', composition]]
    panes << [:setup, 'ruby', setup] unless setup.empty?
    panes
  end

  def self.css_slice(src, from, upto)
    src[src.index(from)...src.index(upto)].rstrip
  end

  ICONS = {
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
    code: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
    style: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"/></svg>',
    tailwind: '<svg viewBox="0 0 54 33" fill="currentColor"><path d="M27 0c-7.2 0-11.7 3.6-13.5 10.8 2.7-3.6 5.85-4.95 9.45-4.05 2.054.513 3.522 2.004 5.147 3.653C30.744 13.09 33.808 16.2 40.5 16.2c7.2 0 11.7-3.6 13.5-10.8-2.7 3.6-5.85 4.95-9.45 4.05-2.054-.513-3.522-2.004-5.147-3.653C36.756 3.11 33.692 0 27 0zM13.5 16.2C6.3 16.2 1.8 19.8 0 27c2.7-3.6 5.85-4.95 9.45-4.05 2.054.514 3.522 2.004 5.147 3.653C17.244 29.29 20.308 32.4 27 32.4c7.2 0 11.7-3.6 13.5-10.8-2.7 3.6-5.85 4.95-9.45 4.05-2.054-.513-3.522-2.004-5.147-3.653C23.256 19.31 20.192 16.2 13.5 16.2z"/></svg>',
    script: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5a2 2 0 0 0 2 2h1"/><path d="M16 3h1a2 2 0 0 1 2 2v5a2 2 0 0 0 2 2 2 2 0 0 0-2 2v5a2 2 0 0 1-2 2h-1"/></svg>',
    setup: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="21" x2="14" y1="4" y2="4"/><line x1="10" x2="3" y1="4" y2="4"/><line x1="21" x2="12" y1="12" y2="12"/><line x1="8" x2="3" y1="12" y2="12"/><line x1="21" x2="16" y1="20" y2="20"/><line x1="12" x2="3" y1="20" y2="20"/><line x1="14" x2="14" y1="2" y2="6"/><line x1="8" x2="8" y1="10" y2="14"/><line x1="16" x2="16" y1="18" y2="22"/></svg>',
  }.freeze

  PANE_LABELS = { code: 'Component code', setup: 'Setup', style: 'Theme CSS', tailwind: 'Tailwind styling', script: 'Stimulus controller' }.freeze

  # Both shown in the Stimulus pane and executed on the page, so they cannot drift.
  STIMULUS_CONTROLLER_JS = <<~JS
    import { Application } from '@hotwired/stimulus'
    import CmdkController from 'cmdk_controller'

    // Extend the gem's base controller and override only the hooks you need.
    class PaletteController extends CmdkController {
      itemSelected(event) { this.log(`selected     ${event.detail.value}`) }
      valueChanged(event)  { this.log(`highlighted  ${event.detail.value}`) }
      searchChanged(event) { this.log(`search       ${JSON.stringify(event.detail)}`) }

      log(line) {
        const out = this.element.querySelector('[data-palette-log]')
        out.textContent = line + '\\n' + out.textContent
      }
    }

    Application.start().register('palette', PaletteController)
  JS

  EXAMPLES = [
    { group: 'Basics', title: 'Default',
      desc: 'Groups, separators, keywords and a disabled item. Navigate with arrow keys, ctrl+n/j/p/k, Home and End; select with Enter.',
      scenario: -> { Scenarios::Menu.new },
      panes: ruby_panes('Menu') },
    { group: 'Basics', title: 'Plain items',
      desc: 'No groups; when value: is omitted it is inferred from the rendered text content.',
      scenario: -> { Scenarios::PlainItems.new },
      panes: ruby_panes('PlainItems') },
    { group: 'Basics', title: 'Force mount',
      desc: "Type 'zzz' and watch force-mounted entries ignore filtering.",
      scenario: -> { Scenarios::ForceMount.new },
      panes: ruby_panes('ForceMount') },
    { group: 'Extensions', title: 'Scoped search',
      desc: "An extension over the vanilla filter: narrow the search to a scope you pick, with groups that stay hidden until their scope is active.",
      scenario: -> { Scenarios::ScopedSearch.new },
      panes: ruby_panes('ScopedSearch') },
    { group: 'Extensions', title: 'Footer hints',
      desc: 'The footer follows the selection: each item declares hint:/kbd:. Shown in the Raycast theme port.',
      scenario: -> { Scenarios::Themed.new(theme: 'cmdk-raycast') },
      panes: [*ruby_panes('Themed'),
              [:style, 'css', css_slice(THEME_CSS_SRC, '/* ── Raycast', '/* Prevent iOS')]] },
    { group: 'States', title: 'Loading',
      desc: 'Render Cmdk::Loading while fetching asynchronous items.',
      scenario: -> { Scenarios::Loading.new },
      panes: ruby_panes('Loading') },
    { group: 'States', title: 'Empty state',
      desc: 'Cmdk::Empty shows whenever there are no results.',
      scenario: -> { Scenarios::Empty.new },
      panes: ruby_panes('Empty') },
    { group: 'Events', title: 'Event wiring',
      desc: 'Everything you would wire as a callback arrives as a bubbling DOM event. Interact and watch the log.',
      scenario: -> { Scenarios::Events.new },
      panes: ruby_panes('Events') },
    { group: 'Events', title: 'Stimulus controller',
      desc: 'The same events, wired through the optional Stimulus base controller: extend CmdkController and override its hooks (itemSelected, valueChanged, searchChanged, scopeChanged).',
      scenario: -> { Scenarios::StimulusEvents.new },
      panes: [*ruby_panes('StimulusEvents'), [:script, 'js', STIMULUS_CONTROLLER_JS]] },
    { group: 'Custom themes', title: 'CRT terminal',
      desc: 'A look built from scratch: scanlines, phosphor glow, inverted selection. Plain CSS against the cmdk attribute contract.',
      scenario: -> { Scenarios::CustomTheme.new },
      panes: [*ruby_panes('CustomTheme'),
              [:style, 'css', css_slice(SITE_CSS_SRC, '/* >>> cmdk-terminal */', '/* <<< cmdk-terminal */')]] },
    { group: 'Custom themes', title: 'Neo-brutalism',
      desc: 'No stylesheet at all: thick borders, hard shadows and pressed-button selection, built entirely from Tailwind utilities and data-[...] variants on the components.',
      scenario: -> { Scenarios::TailwindTheme.new },
      panes: ruby_panes('TailwindTheme', code: :tailwind) },
  ].freeze

  def view_template
    render SitePage.new(title: 'Examples · phlex-cmdk', current: 'Examples') do
      main(class: 'mx-auto flex w-full max-w-6xl gap-10 px-6 pt-10 pb-20') do
        # Side nav: jump to an example; the one nearest the top highlights.
        nav(class: 'examples-nav', aria_label: 'Examples') do
          EXAMPLES.chunk { |e| e[:group] }.each do |group, items|
            span(class: 'examples-nav-group') { group }
            items.each do |example|
              slug = example_slug(example[:title])
              a(href: "##{slug}", data: { nav: slug }) { example[:title] }
            end
          end
        end

        div(class: 'flex min-w-0 flex-1 flex-col gap-16') do
          EXAMPLES.each do |example|
            section(id: example_slug(example[:title]), class: 'example-section flex flex-col items-center gap-4', data: { freeze_height: '' }) do
              # Header column at the menu's width so the title, description and
              # menu all share the same left edge.
              div(class: 'flex w-full max-w-[40rem] flex-col gap-1.5') do
                div(class: 'flex items-center justify-between gap-3') do
                  h2(class: 'text-lg font-semibold') { example[:title] }
                  div(class: 'seg-group shrink-0', role: 'group', aria_label: 'View as') do
                    seg_button('preview', :eye, 'Live preview', active: true)
                    example[:panes].each_with_index do |(kind, _, _), index|
                      seg_button(index.to_s, kind, PANE_LABELS[kind])
                    end
                  end
                end
                p(class: 'demo-hint text-sm') { example[:desc] }
              end

              div(class: 'flex w-full justify-center', data: { pane: 'preview' }) do
                render example[:scenario].call
              end
              example[:panes].each_with_index do |(_, lang, source), index|
                pre(class: 'code-pane mx-auto w-full max-w-[40rem]', hidden: true, data: { pane: index.to_s }) do
                  code(class: "language-#{lang}") { source }
                end
              end
            end
          end
        end

        # Mirrors the nav's width so the content column stays centered on the page.
        div(class: 'examples-nav-spacer', aria_hidden: 'true')

        script { raw safe(<<~JS) }
          document.addEventListener('click', (event) => {
            const button = event.target.closest('[data-pane-btn]')
            if (!button) return
            const section = button.closest('section')
            section.querySelectorAll('[data-pane-btn]').forEach((b) => b.classList.toggle('active', b === button))
            section.querySelectorAll('[data-pane]').forEach((p) => { p.hidden = p.dataset.pane !== button.dataset.paneBtn })
          })

          // Highlight the side-nav link for the example nearest the top.
          const navLinks = [...document.querySelectorAll('[data-nav]')]
          const sections = [...document.querySelectorAll('.example-section')]
          const syncNav = () => {
            let current = sections[0]
            for (const s of sections) { if (s.getBoundingClientRect().top <= 120) current = s }
            navLinks.forEach((l) => l.classList.toggle('active', !!current && l.dataset.nav === current.id))
          }
          addEventListener('scroll', syncNav, { passive: true })
          addEventListener('resize', syncNav)
          addEventListener('load', syncNav)
          syncNav()
        JS

        # Registers the palette controller for the Stimulus example above.
        # Same source as its "Stimulus controller" pane, so the two never drift.
        script(type: 'module') { raw safe(STIMULUS_CONTROLLER_JS) }
      end
    end
  end

  private

  def example_slug(title)
    title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
  end

  def seg_button(target, icon_name, label, active: false)
    button(class: "seg-btn#{' active' if active}", type: 'button',
           data: { pane_btn: target }, aria_label: label, title: label) do
      raw safe(ICONS[icon_name])
    end
  end
end

class DocsPage < Phlex::HTML
  def initialize(readme_html:)
    @readme_html = readme_html
  end

  def view_template
    render SitePage.new(title: 'Docs · phlex-cmdk', current: 'Docs') do
      main(class: 'markdown mx-auto max-w-3xl px-4 pt-8 pb-16') do
        raw safe(@readme_html)
      end
    end
  end
end

class StylingPage < Phlex::HTML
  # [selector queried within the menu, side, label shown, one-line description]
  CALLOUTS = [
    ['[cmdk-scope-pill]', 'left', '[cmdk-scope-pill]', 'Pinned scope in scoped search.'],
    ['[cmdk-group-heading]', 'left', '[cmdk-group-heading]', 'Optional label for a group.'],
    ['[cmdk-group]', 'left', '[cmdk-group]', 'Wraps a set of related items.', true],
    ['[cmdk-group]:last-of-type [cmdk-item]', 'left', '[cmdk-item]', 'A result row.'],
    ['[cmdk-footer]', 'left', '[cmdk-footer]', 'Optional footer bar.'],
    ['[cmdk-input]', 'right', '[cmdk-input]', 'The search box. Filters as you type.'],
    ['[cmdk-item][data-selected=\'true\']', 'right', '[data-selected]', 'The active row (keyboard or pointer).'],
    ['[cmdk-separator]', 'right', '[cmdk-separator]', 'Divider between sections.'],
    ['[cmdk-footer-hint]', 'right', '[cmdk-footer-hint]', 'Hint that tracks the selected row.'],
  ].freeze

  REFERENCE = [
    ['[cmdk-root]', 'The command menu container.'],
    ['[cmdk-input]', 'The search input (a combobox).'],
    ['[cmdk-list]', 'Scrollable results region. Animate height with the --cmdk-list-height variable.'],
    ['[cmdk-group] / [cmdk-group-heading]', 'A group and its optional heading.'],
    ['[cmdk-item]', 'A result. State hooks: [data-selected], [data-disabled].'],
    ['[cmdk-separator]', 'A divider; hidden while searching unless always_render.'],
    ['[cmdk-empty]', 'Shown when nothing matches.'],
    ['[cmdk-loading]', 'Async loading indicator.'],
    ['[cmdk-footer] / [cmdk-footer-hint]', 'Footer and its selection-driven hint (extension).'],
    ['[cmdk-scope-pill]', 'The pinned scope chip. Carries [data-scope="name"], so you can style each scope and fall back to the bare selector (extension).'],
  ].freeze

  def view_template
    render SitePage.new(title: 'Styling · phlex-cmdk', current: 'Styling') do
      main(class: 'mx-auto flex w-full max-w-5xl flex-col gap-12 px-6 pt-10 pb-20') do
        section(class: 'max-w-prose') do
          h1(class: 'text-3xl font-semibold tracking-tight') { 'Styling' }
          p(class: 'demo-hint mt-3 text-sm leading-relaxed') do
            plain 'The components expose a stable '
            code(class: 'demo-chip') { 'cmdk-*' }
            plain ' attribute contract. The shipped stylesheet gives a sensible default '
            plain 'driven by '
            code(class: 'demo-chip') { '--cmdk-*' }
            plain ' tokens, so you re-theme by overriding a few variables, or target the '
            plain 'attributes directly from plain CSS, SCSS or Tailwind.'
          end
        end

        # Annotated anatomy: leader lines from each label to its element (drawn
        # on load/resize). On narrow screens the columns hide; the reference
        # list below covers the same ground.
        section(class: 'anatomy-stage', data: { anatomy_stage: '' }) do
          svg(class: 'anatomy-lines', aria_hidden: 'true')
          div(class: 'anatomy-col anatomy-col-left') do
            CALLOUTS.select { |c| c[1] == 'left' }.each { |c| anatomy_label(*c) }
          end
          div(class: 'anatomy-menu') { anatomy_menu }
          div(class: 'anatomy-col anatomy-col-right') do
            CALLOUTS.select { |c| c[1] == 'right' }.each { |c| anatomy_label(*c) }
          end
        end

        section(class: 'flex flex-col gap-4') do
          h2(class: 'text-lg font-semibold') { 'Every part, by selector' }
          dl(class: 'anatomy-ref') do
            REFERENCE.each do |selector, desc|
              div(class: 'anatomy-ref-row') do
                # Entries like "[cmdk-group] / [cmdk-group-heading]" become one
                # chip per selector, each on its own line.
                dt do
                  selector.split(' / ').each { |sel| code(class: 'demo-chip') { sel } }
                end
                dd(class: 'demo-hint') { desc }
              end
            end
          end
        end

        # Base-theme builder: token controls drive a live preview and a copyable
        # block of overrides (one JS template feeds both).
        section(class: 'flex flex-col gap-4') do
          div(class: 'max-w-prose') do
            h2(class: 'text-lg font-semibold') { 'Build your base theme' }
            p(class: 'demo-hint mt-1 text-sm') do
              plain 'Shape the default look by tuning its tokens; the preview updates live. Copy the '
              code(class: 'demo-chip') { 'light-dark()' }
              plain ' overrides as CSS or Tailwind and drop them on a '
              code(class: 'demo-chip') { "class: 'cmdk'" }
              plain ' root. Statement looks like the CRT terminal and neo-brutalism are built with '
              plain 'structure, not tokens, so they live on the '
              a(href: './examples.html', class: 'underline') { 'Examples' }
              plain ' page instead.'
            end
          end

          # Preset buttons (built from PRESETS in the script below). Seeding from
          # one warns first if the tokens have been changed.
          div(class: 'builder-presets') do
            span(class: 'demo-hint builder-presets-label') { 'Start from' }
            div(class: 'builder-preset-list', id: 'builder-presets')
          end

          div(class: 'builder') do
            # Controls are built from the config in the script below (single
            # source of truth for the elements, their properties and defaults).
            div(class: 'builder-controls', id: 'builder-controls')
            div(class: 'builder-preview') { builder_menu }
          end

          div(class: 'builder-output-wrap') do
            div(class: 'builder-output-bar') do
              div(class: 'builder-format', role: 'tablist', aria_label: 'Output format') do
                span(class: 'builder-format-thumb', aria_hidden: 'true')
                button(type: 'button', class: 'builder-format-btn', role: 'tab',
                       data: { format: 'css' }, aria_selected: 'true') { 'CSS' }
                button(type: 'button', class: 'builder-format-btn', role: 'tab',
                       data: { format: 'tailwind' }, aria_selected: 'false') { 'Tailwind' }
              end
              button(type: 'button', class: 'copy-button', data: { builder_copy: '' }, aria_label: 'Copy') { raw safe(COPY_ICON_HTML) }
            end
            style(id: 'builder-style') { '' }
            pre(class: 'builder-output') { code(class: 'builder-code') }
          end
        end

        script { raw safe(<<~JS) }
          // The base theme reads these tokens, so the builder only emits token
          // overrides — re-theming the whole menu by setting a handful of vars.
          const GROUPS = [
            { label: 'Container', controls: [
              { v: '--cmdk-bg', label: 'Background', kind: 'color', l: '#ffffff', d: '#18181b' },
              { v: '--cmdk-fg', label: 'Text', kind: 'color', l: '#171717', d: '#ededef' },
              { v: '--cmdk-border', label: 'Border', kind: 'color', l: '#e5e5e5', d: '#27272a' },
              { v: '--cmdk-radius', label: 'Radius', kind: 'px', n: 12, max: 24 } ] },
            { label: 'Muted', controls: [
              { v: '--cmdk-muted', label: 'Headings, footer, placeholder', kind: 'color', l: '#a3a3a3', d: '#71717a' } ] },
            { label: 'Item', controls: [
              { v: '--cmdk-item-radius', label: 'Radius', kind: 'px', n: 8, max: 24 },
              { v: '--cmdk-item-height', label: 'Height', kind: 'px', n: 40, min: 28, max: 56, step: 4 } ] },
            { label: 'Selected item', controls: [
              { v: '--cmdk-accent', label: 'Background', kind: 'color', l: '#f5f5f5', d: '#27272a' },
              { v: '--cmdk-accent-fg', label: 'Text', kind: 'color', l: '#0a0a0a', d: '#fafafa' } ] },
            { label: 'Scope pill', controls: [
              { v: '--cmdk-pill', label: 'Background', kind: 'color', l: '#e5e5e5', d: '#3f3f46' },
              { v: '--cmdk-pill-fg', label: 'Text', kind: 'color', l: '#404040', d: '#d4d4d8' },
              { v: '--cmdk-pill-radius', label: 'Radius', kind: 'px', n: 6, max: 16 } ] },
          ]
          const CONTROLS = GROUPS.flatMap((g) => g.controls)

          const controlsEl = document.getElementById('builder-controls')
          const styleEl = document.getElementById('builder-style')
          let format = 'css'

          const legend = document.createElement('div')
          legend.className = 'builder-legend'
          legend.innerHTML = '<span></span><div class="builder-pair">' +
            '<span class="builder-pair-label">Light</span><span class="builder-pair-label">Dark</span></div>'
          controlsEl.appendChild(legend)
          GROUPS.forEach((g) => {
            const head = document.createElement('h3')
            head.className = 'builder-group-label'
            head.textContent = g.label
            controlsEl.appendChild(head)
            g.controls.forEach((c) => {
              const row = document.createElement('div')
              row.className = 'builder-control'
              const lab = document.createElement('label')
              lab.className = 'builder-control-label'
              lab.textContent = c.label
              row.appendChild(lab)
              if (c.kind === 'color') {
                const pair = document.createElement('div')
                pair.className = 'builder-pair'
                ;[['L', c.l, 'light'], ['D', c.d, 'dark']].forEach(([side, val, name]) => {
                  const inp = document.createElement('input')
                  inp.type = 'color'
                  inp.className = 'builder-color'
                  inp.value = val
                  inp.dataset.k = c.v + side
                  inp.setAttribute('aria-label', `${g.label} ${c.label}, ${name}`)
                  pair.appendChild(inp)
                })
                row.appendChild(pair)
              } else {
                const sw = document.createElement('div')
                sw.className = 'builder-swatch'
                const inp = document.createElement('input')
                inp.type = 'range'
                inp.min = String(c.min || 0)
                inp.max = String(c.max || 24)
                if (c.step) inp.step = String(c.step)
                inp.value = String(c.n)
                inp.dataset.k = c.v
                inp.setAttribute('aria-label', `${g.label} ${c.label}`)
                const out = document.createElement('span')
                out.className = 'builder-control-value'
                out.dataset.for = c.v
                out.textContent = c.n + 'px'
                sw.append(inp, out)
                row.appendChild(sw)
              }
              controlsEl.appendChild(row)
            })
          })

          const inputs = [...controlsEl.querySelectorAll('[data-k]')]
          const readVals = () => {
            const t = {}
            inputs.forEach((el) => {
              t[el.dataset.k] = el.value
              if (el.type === 'range') {
                const out = controlsEl.querySelector(`[data-for="${el.dataset.k}"]`)
                if (out) out.textContent = el.value + 'px'
              }
            })
            return t
          }

          // The output is a small block of token overrides — the base theme
          // (class: 'cmdk') does the rest. CSS form: override the tokens.
          const cssText = (t, selector) => {
            const lines = CONTROLS.map((c) => c.kind === 'color'
              ? `  ${c.v}: light-dark(${t[c.v + 'L']}, ${t[c.v + 'D']});`
              : `  ${c.v}: ${t[c.v]}px;`)
            return `${selector} {\\n${lines.join('\\n')}\\n}`
          }

          // Tailwind form: the base class plus the token overrides as arbitrary
          // properties on the root.
          const twText = (t) => {
            const u = CONTROLS.map((c) => c.kind === 'color'
              ? `[${c.v}:${t[c.v + 'L']}] dark:[${c.v}:${t[c.v + 'D']}]`
              : `[${c.v}:${t[c.v]}px]`).join(' ')
            return [
              `# The cmdk class applies the base theme; the rest override tokens.`,
              `Cmdk::Root(class: "cmdk ${u}") do`,
              `  # ... input, list, groups, items`,
              `end`,
            ].join('\\n')
          }

          // Highlight the output via highlight.js (loaded with defer, so paint
          // again on load); copying reads textContent, which strips the markup.
          const codeEl = document.querySelector('.builder-code')
          const paint = (text, lang) => {
            codeEl.className = `builder-code hljs language-${lang}`
            if (window.hljs) codeEl.innerHTML = hljs.highlight(text, { language: lang }).value
            else codeEl.textContent = text
          }
          const apply = () => {
            const t = readVals()
            // Live preview overrides the tokens scoped to its container, so it
            // re-themes only the preview, not the page's other menus.
            styleEl.textContent = cssText(t, '.builder-preview [cmdk-root]')
            if (format === 'tailwind') paint(twText(t), 'ruby')
            else paint(cssText(t, ':root'), 'css')
          }
          inputs.forEach((el) => el.addEventListener('input', apply))
          addEventListener('load', apply)
          const thumb = document.querySelector('.builder-format-thumb')
          const moveThumb = (animate = true) => {
            const active = document.querySelector(".builder-format-btn[aria-selected='true']")
            if (!active || !thumb) return
            if (!animate) thumb.style.transition = 'none'
            thumb.style.width = active.offsetWidth + 'px'
            thumb.style.transform = 'translateX(' + active.offsetLeft + 'px)'
            if (!animate) { void thumb.offsetWidth; thumb.style.transition = '' }
          }
          document.querySelectorAll('.builder-format-btn').forEach((btn) => {
            btn.addEventListener('click', () => {
              format = btn.dataset.format
              document.querySelectorAll('.builder-format-btn').forEach((b) =>
                b.setAttribute('aria-selected', String(b === btn)))
              moveThumb()
              apply()
            })
          })
          // Position instantly on first paint and on resize (no grow-in animation).
          moveThumb(false)
          addEventListener('load', () => moveThumb(false))
          addEventListener('resize', () => moveThumb(false))
          const copyBtn = document.querySelector('[data-builder-copy]')
          copyBtn.addEventListener('click', () => {
            window.copyText(codeEl.textContent)
            copyBtn.classList.add('copied')
            clearTimeout(copyBtn._copyTimer)
            copyBtn._copyTimer = setTimeout(() => copyBtn.classList.remove('copied'), 2000)
          })

          // Presets seed the tokens from the shipped themes. These are the
          // token-driven themes, so they reproduce faithfully — the statement
          // demo themes (Terminal, Brutalism) are intentionally not here: their
          // look is structural (monospace, thick borders), not token-driven.
          const PRESETS = {
            Vercel: {
              '--cmdk-bg': ['#ffffff', '#18181b'], '--cmdk-fg': ['#171717', '#ededef'],
              '--cmdk-border': ['#e5e5e5', '#27272a'], '--cmdk-muted': ['#a3a3a3', '#71717a'],
              '--cmdk-accent': ['#f5f5f5', '#27272a'], '--cmdk-accent-fg': ['#0a0a0a', '#fafafa'],
              '--cmdk-pill': ['#e5e5e5', '#3f3f46'], '--cmdk-pill-fg': ['#404040', '#d4d4d8'],
              '--cmdk-radius': 12, '--cmdk-item-radius': 8, '--cmdk-pill-radius': 6, '--cmdk-item-height': 40,
            },
            Linear: {
              '--cmdk-bg': ['#ffffff', '#27282b'], '--cmdk-fg': ['#282a30', '#ededef'],
              '--cmdk-border': ['#e9e8ea', '#3c3d40'], '--cmdk-muted': ['#6f7177', '#8a8f98'],
              '--cmdk-accent': ['#f0f0f1', '#313135'], '--cmdk-accent-fg': ['#282a30', '#ededef'],
              '--cmdk-pill': ['#ecedf6', '#34364d'], '--cmdk-pill-fg': ['#5e6ad2', '#b1b8f5'],
              '--cmdk-radius': 8, '--cmdk-item-radius': 0, '--cmdk-pill-radius': 6, '--cmdk-item-height': 48,
            },
            Raycast: {
              '--cmdk-bg': ['#fdfcfd', '#1c1c1f'], '--cmdk-fg': ['#282a30', '#ededef'],
              '--cmdk-border': ['#e4e2e4', '#2e2e32'], '--cmdk-muted': ['#6f7177', '#8a8f98'],
              '--cmdk-accent': ['#ededee', '#2c2c30'], '--cmdk-accent-fg': ['#282a30', '#ededef'],
              '--cmdk-pill': ['#ededee', '#2c2c30'], '--cmdk-pill-fg': ['#282a30', '#ededef'],
              '--cmdk-radius': 12, '--cmdk-item-radius': 8, '--cmdk-pill-radius': 6, '--cmdk-item-height': 40,
            },
          }
          const byKey = {}
          inputs.forEach((el) => { byKey[el.dataset.k] = el })
          const snapshot = () => inputs.map((el) => el.value).join('|')
          let clean = snapshot()
          const presetsEl = document.getElementById('builder-presets')
          Object.keys(PRESETS).forEach((name) => {
            const btn = document.createElement('button')
            btn.type = 'button'
            btn.className = 'builder-preset'
            btn.textContent = name
            btn.addEventListener('click', () => {
              // Warn before discarding edits the user has made to the tokens.
              if (snapshot() !== clean && !confirm(`Replace your changes with the ${name} preset?`)) return
              const p = PRESETS[name]
              CONTROLS.forEach((c) => {
                if (c.kind === 'color') {
                  byKey[c.v + 'L'].value = p[c.v][0]
                  byKey[c.v + 'D'].value = p[c.v][1]
                } else {
                  byKey[c.v].value = String(p[c.v])
                }
              })
              apply()
              clean = snapshot()
            })
            presetsEl.appendChild(btn)
          })

          apply()
        JS

        script { raw safe(<<~JS) }
          const stage = document.querySelector('[data-anatomy-stage]')
          const svg = stage.querySelector('.anatomy-lines')
          const menu = stage.querySelector('[cmdk-root]')
          const labels = Array.from(stage.querySelectorAll('.anatomy-label'))
          const ns = 'http://www.w3.org/2000/svg'
          const roundRect = (x, y, w, h, r) => {
            r = Math.max(0, Math.min(r, w / 2, h / 2))
            return `M${x + r},${y} h${w - 2 * r} a${r},${r} 0 0 1 ${r},${r}` +
              ` v${h - 2 * r} a${r},${r} 0 0 1 ${-r},${r} h${-(w - 2 * r)}` +
              ` a${r},${r} 0 0 1 ${-r},${-r} v${-(h - 2 * r)} a${r},${r} 0 0 1 ${r},${-r} z`
          }
          const radiusOf = (el) => {
            // Coordinates come from getBoundingClientRect (which includes any
            // CSS zoom), but getComputedStyle reports unzoomed lengths, so scale
            // the radius by the zoom chain to keep it in the same units.
            let zoom = 1
            for (let n = el; n; n = n.parentElement) zoom *= parseFloat(getComputedStyle(n).zoom) || 1
            return (parseFloat(getComputedStyle(el).borderTopLeftRadius) || 0) * zoom
          }
          const draw = () => {
            const box = stage.getBoundingClientRect()
            const menuBox = menu.getBoundingClientRect()
            svg.setAttribute('viewBox', `0 0 ${box.width} ${box.height}`)
            svg.replaceChildren()
            if (getComputedStyle(stage.querySelector('.anatomy-col-left')).display === 'none') return
            // Scrim first so it sits behind the leader lines and dots.
            const scrim = document.createElementNS(ns, 'path')
            scrim.setAttribute('class', 'anatomy-scrim')
            scrim.setAttribute('fill-rule', 'evenodd')
            svg.appendChild(scrim)
            labels.forEach((label, i) => {
              const target = menu.querySelector(label.dataset.target)
              if (!target) return
              label.dataset.i = i
              const left = label.dataset.side === 'left'
              const lr = label.getBoundingClientRect()
              const tr = target.getBoundingClientRect()
              const lx = (left ? lr.right : lr.left) - box.left
              const ly = lr.top + lr.height / 2 - box.top
              const edgeX = (left ? tr.left : tr.right) - box.left
              const ty = tr.top + tr.height / 2 - box.top
              const bracketed = 'bracket' in label.dataset
              // A bracket sits in the gutter just outside the menu, so a
              // container reads as a margin brace enveloping its rows, never as
              // a dot aimed at one of them.
              const cx = bracketed
                ? (left ? menuBox.left - box.left - 8 : menuBox.right - box.left + 8)
                : edgeX
              const stub = left ? lx + 18 : lx - 18
              const line = document.createElementNS(ns, 'polyline')
              line.setAttribute('points', `${lx},${ly} ${stub},${ly} ${cx},${ty}`)
              line.setAttribute('class', 'anatomy-line')
              line.dataset.i = i
              svg.appendChild(line)
              if (bracketed) {
                const top = tr.top - box.top
                const bot = tr.bottom - box.top
                const reach = left ? 9 : -9
                const bracket = document.createElementNS(ns, 'polyline')
                bracket.setAttribute('points', `${cx + reach},${top} ${cx},${top} ${cx},${bot} ${cx + reach},${bot}`)
                bracket.setAttribute('class', 'anatomy-bracket')
                bracket.dataset.i = i
                svg.appendChild(bracket)
              } else {
                const dot = document.createElementNS(ns, 'circle')
                dot.setAttribute('cx', edgeX); dot.setAttribute('cy', ty); dot.setAttribute('r', '3')
                dot.setAttribute('class', 'anatomy-dot')
                dot.dataset.i = i
                svg.appendChild(dot)
              }
            })
            // Rebuilding drops the scrim, so re-apply any active isolation
            // (e.g. when the viewport resizes while a label is hovered).
            const active = labels.find((l) => l.classList.contains('is-active'))
            if (active) focus(active)
          }
          addEventListener('load', draw)
          addEventListener('resize', draw)

          // Hovering a label isolates its element: a scrim darkens the whole
          // menu with a rounded hole punched around the target, so its
          // boundaries read crisply.
          const focus = (label) => {
            const target = menu.querySelector(label.dataset.target)
            if (!target) return
            stage.classList.add('anatomy-isolating')
            labels.forEach((l) => l.classList.toggle('is-active', l === label))
            svg.querySelectorAll('[data-i]').forEach((el) =>
              el.classList.toggle('is-active', el.dataset.i === label.dataset.i))
            const scrim = svg.querySelector('.anatomy-scrim')
            if (!scrim) return
            const box = stage.getBoundingClientRect()
            const mr = menu.getBoundingClientRect()
            const tr = target.getBoundingClientRect()
            const pad = 3
            // Both the scrim edge and the cutout share the menu's corner radius.
            const r = radiusOf(menu)
            const outer = roundRect(mr.left - box.left, mr.top - box.top, mr.width, mr.height, r)
            const hole = roundRect(
              tr.left - box.left - pad, tr.top - box.top - pad,
              tr.width + 2 * pad, tr.height + 2 * pad, r)
            scrim.setAttribute('d', `${outer} ${hole}`)
            scrim.classList.add('is-on')
          }
          const clearFocus = () => {
            stage.classList.remove('anatomy-isolating')
            labels.forEach((l) => l.classList.remove('is-active'))
            svg.querySelectorAll('.is-active').forEach((el) => el.classList.remove('is-active'))
            svg.querySelector('.anatomy-scrim')?.classList.remove('is-on')
          }
          labels.forEach((label) => {
            label.addEventListener('mouseenter', () => focus(label))
            label.addEventListener('mouseleave', clearFocus)
          })
        JS
      end
    end
  end

  private

  def builder_menu
    Cmdk::Root(label: 'Theme preview', loop: true, scopes: %w[fruits], class: 'cmdk w-full max-w-[28rem]') do
      div(class: 'cmdk-search-row') do
        Cmdk::Input(placeholder: "Search, or type '/' for scopes…")
      end
      Cmdk::List() do
        Cmdk::Empty() { 'No results found.' }
        Cmdk::Group(heading: 'Suggestions') do
          Cmdk::Item(value: 'fruits', enters_scope: 'fruits', keywords: %w[apple banana orange]) { entry('🍎', 'Search fruits…') }
          Cmdk::Item(value: 'Search Docs') { entry('🔍', 'Search Docs') }
          Cmdk::Item(value: 'New File') { entry('📄', 'New File') }
        end
        Cmdk::Separator()
        Cmdk::Group(heading: 'Account') do
          Cmdk::Item(value: 'Profile') { entry('🧑', 'Profile') }
          Cmdk::Item(value: 'Log Out', disabled: true) { entry('🚪', 'Log Out') }
        end
        Cmdk::Group(heading: 'Fruits', scope: 'fruits', scope_only: true) do
          Cmdk::Item(value: 'Apple') { entry('🍎', 'Apple') }
          Cmdk::Item(value: 'Banana') { entry('🍌', 'Banana') }
          Cmdk::Item(value: 'Orange') { entry('🍊', 'Orange') }
        end
      end
      Cmdk::Footer() { span(class: 'demo-hint') { 'Live preview' } }
    end
  end

  def anatomy_label(target, side, name, desc, bracket = false)
    data = { target: target, side: side }
    data[:bracket] = '' if bracket
    div(class: 'anatomy-label', data: data) do
      code(class: 'anatomy-label-name') { name }
      span(class: 'demo-hint anatomy-label-desc') { desc }
    end
  end

  def anatomy_menu
    Cmdk::Root(label: 'Anatomy', class: 'cmdk-vercel w-96') do
      # A static pill (not a live scope) so the diagram can point at it.
      div(class: 'cmdk-search-row') do
        button('cmdk-scope-pill' => '', 'data-scope' => 'fruits', type: 'button', aria_hidden: 'true', tabindex: '-1') { 'fruits' }
        # Non-focusable: keeps the diagram inert so tabbing/typing can't move
        # the selection off the labelled row (pointer-events are blocked in CSS).
        Cmdk::Input(placeholder: 'Search…', tabindex: '-1', readonly: true, aria_hidden: 'true')
      end
      Cmdk::List() do
        Cmdk::Empty() { 'No results found.' }
        Cmdk::Group(heading: 'Suggestions') do
          Cmdk::Item(value: 'Search Docs', hint: 'Open', kbd: '↵') { entry('🔍', 'Search Docs') }
          Cmdk::Item(value: 'New File') { entry('📄', 'New File') }
        end
        Cmdk::Separator()
        Cmdk::Group(heading: 'Account') do
          Cmdk::Item(value: 'Profile') { entry('🧑', 'Profile') }
          Cmdk::Item(value: 'Log Out', disabled: true) { entry('🚪', 'Log Out') }
        end
      end
      Cmdk::Footer() do
        span(aria_hidden: 'true') { '🚀' }
        div('cmdk-footer-hint' => '')
      end
    end
  end

  def entry(icon, text)
    span(class: 'text-base', aria_hidden: 'true') { icon }
    span { text }
  end
end

# ── build ──

FileUtils.rm_rf(SITE)
FileUtils.mkdir_p(SITE)

FileUtils.cp(Cmdk.javascript_path, File.join(SITE, 'cmdk.js'))
FileUtils.cp(Cmdk.stimulus_controller_path, File.join(SITE, 'cmdk_controller.js'))
FileUtils.cp(File.join(ROOT, 'demo/public/application.css'), File.join(SITE, 'site.css'))

readme_html = Kramdown::Document.new(
  File.read(File.join(ROOT, 'README.md'), encoding: 'UTF-8'),
  input: 'GFM', syntax_highlighter: nil, hard_wrap: false,
).to_html

File.write(File.join(SITE, 'index.html'), PlaygroundPage.new.call)
File.write(File.join(SITE, 'examples.html'), ExamplesPage.new.call)
File.write(File.join(SITE, 'styling.html'), StylingPage.new.call)
File.write(File.join(SITE, 'docs.html'), DocsPage.new(readme_html: readme_html).call)
File.write(File.join(SITE, '.nojekyll'), '')

puts "Built #{Dir[File.join(SITE, '*')].length} files into _site/"
