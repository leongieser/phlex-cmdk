# @label Themes
#
# Ports of the original cmdk themes, styled purely via the `[cmdk-*]`
# attribute contract (see demo/assets/themes.css). Each shows the footer with
# selection-driven hints: select different items and watch the bottom bar.
class CmdkThemesPreview < Lookbook::Preview
  # The Vercel-flavored Tailwind theme used across the other previews.
  def vercel
    render Scenarios::Themed.new(theme: 'cmdk-vercel')
  end

  # Port of the Linear theme: flat list, indigo selection bar on the left.
  def linear
    render Scenarios::Themed.new(theme: 'cmdk-linear')
  end

  # Port of the Raycast theme: rounded items, kbd caps, sticky footer.
  def raycast
    render Scenarios::Themed.new(theme: 'cmdk-raycast')
  end

  # A fully custom CRT terminal look, written from scratch against the
  # attribute contract (demo/assets/application.css, cmdk-terminal block).
  def custom_terminal
    render Scenarios::CustomTheme.new
  end

  # The same terminal look, built purely with Tailwind utilities and
  # data-[...] variants on the components; no stylesheet involved.
  def custom_terminal_tailwind
    render Scenarios::TailwindTheme.new
  end
end
