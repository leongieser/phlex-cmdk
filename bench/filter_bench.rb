# Per-keystroke filtering latency of the JS runtime in headless Chrome.
#
#   bundle exec rake bench            # 200, 1,000 and 5,000 items
#   SIZES=1000,10000 bundle exec rake bench
#   CMDK_JS=/tmp/cmdk-0.1.1.js bundle exec rake bench   # another runtime build
#
# Each keystroke is timed from the input event to a forced style + layout
# (including the runtime's MutationObserver work), so the number is what a
# user waits before the next frame can paint. Fictional data only.
require_relative '../test/browser/support'

SIZES = (ENV['SIZES'] || '200,1000,5000').split(',').map(&:to_i)
ROUNDS = Integer(ENV.fetch('ROUNDS', 5))
QUERIES = ['lighthouse', 'crt ed', 'nrthwnd almnc'].freeze

ADJECTIVES = %w[Amber Brisk Copper Distant Ember Fallow Gilded Harbor Ivory Juniper Kestrel Lantern
                Meadow Northwind Opal Pebble Quiet Russet Saffron Tidal Umber Velvet Willow Yarrow].freeze
NOUNS = %w[Almanac Lighthouse Atlas Bulletin Chronicle Digest Field\ Notes Gazette Herald Index
           Journal Ledger Manual Notebook Orchard Postcard Quarterly Review Sketchbook Timetable].freeze

def fake_title(i)
  "#{ADJECTIVES[i % ADJECTIVES.size]} #{NOUNS[(i / ADJECTIVES.size) % NOUNS.size]} #{i}"
end

def palette(size, highlight: false)
  groups = {
    'Collections' => (size * 0.1).ceil, 'Globals' => (size * 0.05).ceil,
    'Create' => (size * 0.1).ceil
  }
  groups['Recent documents'] = [size - groups.values.sum, 0].max
  n = 0
  CmdkBrowser.render do
    Cmdk::Root(label: 'Command palette', loop: true, class: 'cmdk', id: 'palette') do
      Cmdk::Input(placeholder: 'Search')
      Cmdk::List() do
        Cmdk::Empty() { 'No results' }
        groups.each do |heading, count|
          Cmdk::Group(heading: heading) do
            count.times do
              text = "#{heading == 'Create' ? 'Create' : 'Open'} #{fake_title(n += 1)}"
              Cmdk::Item(value: "#{heading}: #{text}", href: "/cms/x/#{n}") do
                if highlight
                  Cmdk::ItemLabel() { text }
                else
                  plain(text)
                end
              end
            end
          end
        end
      end
    end
  end
end

MEASURE_JS = <<~JS.freeze
  (async (queries, rounds) => {
  const root = document.getElementById('palette')
  const input = root.querySelector('[cmdk-input]')
  const list = root.querySelector('[cmdk-list]')
  const tick = () => new Promise((r) => setTimeout(r, 0))
  const samples = []
    for (let r = 0; r < rounds; r++) {
      for (const query of queries) {
        const steps = []
        for (let i = 1; i <= query.length; i++) steps.push(query.slice(0, i))
        for (let i = query.length - 1; i >= 0; i--) steps.push(query.slice(0, i))
        for (const step of steps) {
          await tick()
          const t0 = performance.now()
          input.value = step
          input.dispatchEvent(new Event('input', { bubbles: true }))
          await null // let the runtime's MutationObserver callbacks run
          list.getBoundingClientRect(); document.body.offsetHeight // force style + layout
          samples.push(performance.now() - t0)
        }
      }
    }
    // Open-time cost: initialise a fresh copy of the menu (what the first
    // keystroke or the dialog open would pay).
    const clone = root.cloneNode(true)
    clone.id = 'palette-clone'
    const t0 = performance.now()
    document.body.appendChild(clone)
    window.Cmdk.getInstance(clone)
    clone.getBoundingClientRect()
    const init = performance.now() - t0
    return { samples, init }
  })(...arguments)
JS

def stats(samples)
  sorted = samples.sort
  pick = ->(q) { sorted[[(q * sorted.size).ceil - 1, 0].max] }
  { median: pick.(0.5), p95: pick.(0.95), max: sorted.last }
end

server = CmdkBrowser::Server.new
browser = CmdkBrowser.browser
highlight = ENV['HIGHLIGHT'] == '1'
puts "phlex-cmdk #{Cmdk::VERSION} — per-keystroke latency (ms), #{ROUNDS} rounds of #{QUERIES.inspect}" \
     "#{highlight ? ', with [cmdk-item-label] highlighting' : ''}"
puts format('%8s %9s %9s %9s %9s', 'items', 'median', 'p95', 'max', 'init')
begin
  SIZES.each do |size|
    html = CmdkBrowser.document(palette(size, highlight: highlight),
                                head: '<link rel="stylesheet" href="/cmdk_themes.css">' \
                                      '<style>[cmdk-list]{max-height:330px;overflow:auto}</style>')
    url = server.page("/bench-#{size}", html)
    page = browser.create_page
    page.go_to(url)
    CmdkBrowser.wait_for(page, 'window.Cmdk?.getState("#palette")')
    result = page.evaluate(MEASURE_JS, QUERIES, ROUNDS, timeout: 300)
    s = stats(result['samples'])
    puts format('%8d %9.2f %9.2f %9.2f %9.2f', size, s[:median], s[:p95], s[:max], result['init'])
    page.close
  end
ensure
  browser.quit
  server.stop
end
