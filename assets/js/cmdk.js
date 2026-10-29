/**
 * cmdk runtime — a dependency-free port of cmdk (React) for server-rendered HTML.
 *
 * Pairs with the `phlex-cmdk` Ruby gem, which renders the same markup contract
 * as the React package (cmdk-* attributes, ARIA roles). This module replicates
 * the React runtime: command-score filtering, group/item sorting, keyboard
 * navigation (including vim bindings), pointer selection, empty state,
 * separators, `--cmdk-list-height`, and a native <dialog> wrapper.
 *
 * It uses document-level event delegation and MutationObservers, so it works
 * with Turbo navigation, morphing and streams without any per-page setup:
 *
 *   import 'cmdk'                  // auto-starts
 *
 * Events (all bubble from within the root):
 *   cmdk-item-select   detail: { value, metaKey, ctrlKey, shiftKey, altKey }
 *                      — item chosen via click or Enter (cancelable); the
 *                        modifier keys held at that moment
 *                        (e.g. ⌘/Ctrl+Enter for an alternate action)
 *   cmdk-value-change  detail: { value }  — selection (highlight) changed
 *   cmdk-search-change detail: { search, scope, query } — search query changed
 *   cmdk-scope-change  detail: { scope, query } — active search scope entered/left
 *
 * Scoped search: declare scopes on the root (`data-cmdk-scopes="user doc"`)
 * and tag items or groups with `data-cmdk-scope="user"`. Typing the picker
 * prefix ("/" by default, `data-cmdk-scope-picker` overrides, "false"
 * disables) suggests items marked `data-cmdk-enters-scope="user"`; selecting
 * one — or typing the name out ("/user ") — pins the scope as a removable
 * pill before the input and leaves only the query text. Backspace on an
 * empty input or a pill click exits the scope. Server-render
 * `data-cmdk-active-scope` on the root to start with a pinned scope. Listen
 * to cmdk-scope-change / cmdk-search-change to fetch scoped results from the
 * server (e.g. via Turbo). Add `data-cmdk-scope-only` to keep items hidden
 * unless their scope is active.
 *
 * Match highlighting (opt-in): mark the text to highlight inside an item with
 * `[cmdk-item-label]` (Cmdk::ItemLabel) and the runtime wraps the matched
 * characters in `<mark cmdk-match>` while searching, restoring the plain text
 * when the search clears.
 *
 * Base styles: unless `<meta name="cmdk-base-styles" content="off">` is in the
 * document, start() injects a small zero-specificity stylesheet (dialog
 * placement), nonced from `<meta name="csp-nonce">` when present. The same
 * rules ship as assets/css/cmdk_base.css for CSP-strict or layered hosts.
 */

// ─────────────────────────────────────────────────────────────────────────────
// command-score (verbatim port of cmdk/src/command-score.ts)
// ─────────────────────────────────────────────────────────────────────────────

const SCORE_CONTINUE_MATCH = 1,
  SCORE_SPACE_WORD_JUMP = 0.9,
  SCORE_NON_SPACE_WORD_JUMP = 0.8,
  SCORE_CHARACTER_JUMP = 0.17,
  SCORE_TRANSPOSITION = 0.1,
  PENALTY_SKIPPED = 0.999,
  PENALTY_CASE_MISMATCH = 0.9999,
  PENALTY_NOT_COMPLETE = 0.99

const IS_GAP_REGEXP = /[\\/_+.#"@[({&]/,
  COUNT_GAPS_REGEXP = /[\\/_+.#"@[({&]/g,
  IS_SPACE_REGEXP = /[\s-]/,
  COUNT_SPACE_REGEXP = /[\s-]/g

// The scoring arithmetic below is unchanged from the port; the memo is a typed
// array instead of string keys (no allocation per call), and `choices`, when
// given, records which index won at each step so the match path can be read
// back for highlighting.
function commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, stringIndex, abbreviationIndex, memo, stride, choices) {
  if (abbreviationIndex === abbreviation.length) {
    if (stringIndex === string.length) {
      return SCORE_CONTINUE_MATCH
    }
    return PENALTY_NOT_COMPLETE
  }

  const memoizeKey = stringIndex * stride + abbreviationIndex
  const memoized = memo[memoizeKey]
  if (memoized >= 0) {
    return memoized
  }

  const abbreviationChar = lowerAbbreviation.charAt(abbreviationIndex)
  let index = lowerString.indexOf(abbreviationChar, stringIndex)
  let highScore = 0
  let choice = -1

  let score, transposedScore, wordBreaks, spaceBreaks, transposed

  while (index >= 0) {
    transposed = false
    score = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 1, memo, stride, choices)
    if (score > highScore) {
      if (index === stringIndex) {
        score *= SCORE_CONTINUE_MATCH
      } else if (IS_GAP_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_NON_SPACE_WORD_JUMP
        wordBreaks = string.slice(stringIndex, index - 1).match(COUNT_GAPS_REGEXP)
        if (wordBreaks && stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, wordBreaks.length)
        }
      } else if (IS_SPACE_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_SPACE_WORD_JUMP
        spaceBreaks = string.slice(stringIndex, index - 1).match(COUNT_SPACE_REGEXP)
        if (spaceBreaks && stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, spaceBreaks.length)
        }
      } else {
        score *= SCORE_CHARACTER_JUMP
        if (stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, index - stringIndex)
        }
      }

      if (string.charAt(index) !== abbreviation.charAt(abbreviationIndex)) {
        score *= PENALTY_CASE_MISMATCH
      }
    }

    if (
      (score < SCORE_TRANSPOSITION && lowerString.charAt(index - 1) === lowerAbbreviation.charAt(abbreviationIndex + 1)) ||
      (lowerAbbreviation.charAt(abbreviationIndex + 1) === lowerAbbreviation.charAt(abbreviationIndex) &&
        lowerString.charAt(index - 1) !== lowerAbbreviation.charAt(abbreviationIndex))
    ) {
      transposedScore = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 2, memo, stride, choices)

      if (transposedScore * SCORE_TRANSPOSITION > score) {
        score = transposedScore * SCORE_TRANSPOSITION
        transposed = true
      }
    }

    if (score > highScore) {
      highScore = score
      choice = index * 2 + (transposed ? 1 : 0)
    }

    index = lowerString.indexOf(abbreviationChar, index + 1)
  }

  memo[memoizeKey] = highScore
  if (choices) choices[memoizeKey] = choice
  return highScore
}

// Lowercased/space-normalised strings are cached: item values repeat on every
// keystroke, so this saves re-normalising each one per query.
const formatted = new Map()

function formatInput(string) {
  let result = formatted.get(string)
  if (result === undefined) {
    result = string.toLowerCase().replace(COUNT_SPACE_REGEXP, ' ')
    if (formatted.size >= 20000) formatted.clear()
    formatted.set(string, result)
  }
  return result
}

// Scratch buffers reused across calls (scoring is synchronous, never re-entered).
let memoBuffer = new Float64Array(4096)
let choiceBuffer = new Int32Array(4096)

function scoreString(string, abbreviation, choices) {
  // +3 keeps a key unique for any abbreviation index the recursion can reach.
  const stride = abbreviation.length + 3
  const size = (string.length + 1) * stride
  if (memoBuffer.length < size) {
    memoBuffer = new Float64Array(size * 2)
    choiceBuffer = new Int32Array(size * 2)
  }
  memoBuffer.fill(-1, 0, size)
  if (choices) {
    choiceBuffer.fill(-1, 0, size)
    choices.array = choiceBuffer
    choices.stride = stride
  }
  return commandScoreInner(string, abbreviation, formatInput(string), formatInput(abbreviation), 0, 0, memoBuffer, stride, choices ? choiceBuffer : null)
}

function joinAliases(string, aliases) {
  return aliases && aliases.length > 0 ? `${string + ' ' + aliases.join(' ')}` : string
}

export function commandScore(string, abbreviation, aliases) {
  return scoreString(joinAliases(string, aliases), abbreviation)
}

/**
 * commandScore plus the positions it matched: `{ score, matches }`, where
 * `matches` are ascending indices into `string` (then into the aliases, joined
 * after it with single spaces). The score is identical to commandScore's;
 * matches is empty when the score is 0. Used for match highlighting.
 */
export function commandScoreWithMatches(string, abbreviation, aliases) {
  const full = joinAliases(string, aliases)
  const choices = {}
  const score = scoreString(full, abbreviation, choices)
  const matches = []
  if (score > 0) {
    const lowerString = formatInput(full)
    const lowerAbbreviation = formatInput(abbreviation)
    let stringIndex = 0
    let abbreviationIndex = 0
    while (abbreviationIndex < abbreviation.length) {
      const choice = choices.array[stringIndex * choices.stride + abbreviationIndex]
      if (choice === undefined || choice < 0) break
      const index = choice >> 1
      if (choice & 1) {
        // A transposition ("ab" typed as "ba") consumed two characters of the
        // abbreviation; a doubled letter ("hhello") consumed only one match.
        if (index > 0 && lowerString.charAt(index - 1) === lowerAbbreviation.charAt(abbreviationIndex + 1)) {
          matches.push(index - 1)
        }
        abbreviationIndex += 2
      } else {
        abbreviationIndex += 1
      }
      matches.push(index)
      stringIndex = index + 1
    }
  }
  return { score, matches: [...new Set(matches)].sort((a, b) => a - b).filter((i) => i < full.length) }
}

// ─────────────────────────────────────────────────────────────────────────────
// Runtime (port of cmdk/src/index.tsx)
// ─────────────────────────────────────────────────────────────────────────────

const ROOT_SELECTOR = '[cmdk-root]'
const INPUT_SELECTOR = '[cmdk-input]'
const LIST_SELECTOR = '[cmdk-list]'
const SIZER_SELECTOR = '[cmdk-list-sizer]'
const GROUP_SELECTOR = '[cmdk-group]'
const GROUP_ITEMS_SELECTOR = '[cmdk-group-items]'
const GROUP_HEADING_SELECTOR = '[cmdk-group-heading]'
const ITEM_SELECTOR = '[cmdk-item]'
const VALID_ITEM_SELECTOR = `${ITEM_SELECTOR}:not([aria-disabled="true"])`
const DIALOG_SELECTOR = 'dialog[cmdk-dialog]'
const ITEM_LABEL_SELECTOR = '[cmdk-item-label]'
const MATCH_ATTR = 'cmdk-match'
const VALUE_ATTR = 'data-value'

const SELECT_EVENT = 'cmdk-item-select'
const VALUE_CHANGE_EVENT = 'cmdk-value-change'
const SEARCH_CHANGE_EVENT = 'cmdk-search-change'

export const defaultFilter = (value, search, keywords) => commandScore(value, search, keywords)

const instances = new WeakMap()
const knownDialogs = new WeakSet()
let globalFilter = defaultFilter
let uid = 0

/** Scope names declared on the root (`data-cmdk-scopes="user doc"`), or null. */
function scopesOf(root) {
  const attr = root.getAttribute('data-cmdk-scopes')
  if (!attr) return null
  const names = attr.split(/\s+/).filter(Boolean)
  return names.length ? names : null
}

/** The scope an item belongs to (own attribute or inherited from its group). */
function itemScope(item) {
  return item.closest('[data-cmdk-scope]')?.getAttribute('data-cmdk-scope') ?? null
}

/** Scope-only elements are hidden unless their scope is active (deliberate entry). */
function isScopeOnly(el) {
  return Boolean(el.closest('[data-cmdk-scope-only]'))
}

/** The scope-picker prefix ("/" by default) — null when disabled or no scopes. */
function pickerChar(root) {
  if (!scopesOf(root)) return null
  const attr = root.getAttribute('data-cmdk-scope-picker')
  if (attr === 'false') return null
  return attr || '/'
}

/** Recompute picker mode and the effective query from the raw search. */
function syncSearchMeta(inst) {
  const pc = pickerChar(inst.root)
  inst.picker = Boolean(!inst.scope && pc && inst.search.startsWith(pc))
  inst.query = inst.picker ? inst.search.slice(pc.length).replace(/^\s+/, '') : inst.search
}

/** Keep the scope pill (a removable chip inserted before the input) in sync. */
function renderPill(inst) {
  const input = inst.root.querySelector(INPUT_SELECTOR)
  let pill = inst.root.querySelector('[cmdk-scope-pill]')
  if (!inst.scope) {
    pill?.remove()
    return
  }
  if (!pill) {
    pill = document.createElement('button')
    pill.type = 'button'
    pill.setAttribute('cmdk-scope-pill', '')
    input?.parentElement?.insertBefore(pill, input)
  }
  pill.textContent = inst.scope
  // Expose the scope name so a pill can be styled per scope
  // (`[cmdk-scope-pill][data-scope="user"]`), falling back to the plain
  // `[cmdk-scope-pill]` rule when no per-scope style is defined.
  pill.setAttribute('data-scope', inst.scope)
  pill.setAttribute('aria-label', `Remove ${inst.scope} filter`)
}

/** Pin a scope: render the pill, leave only the query in the input. */
export function enterScope(target, scope, { query = '', emit = true } = {}) {
  const inst = target.root ? target : getInstance(target)
  if (!inst || inst.scope === scope) return
  inst.scope = scope
  inst.search = query
  syncSearchMeta(inst)
  const input = inst.root.querySelector(INPUT_SELECTOR)
  if (input) input.value = query
  renderPill(inst)
  inst.root.setAttribute('data-cmdk-active-scope', scope)
  filterItems(inst)
  sortItems(inst)
  selectFirstItem(inst, emit ? undefined : { scroll: false, emit: false })
  if (emit) {
    inst.root.dispatchEvent(
      new CustomEvent('cmdk-scope-change', { bubbles: true, detail: { scope, query: inst.query } }),
    )
    inst.root.dispatchEvent(
      new CustomEvent(SEARCH_CHANGE_EVENT, { bubbles: true, detail: { search: inst.search, scope, query: inst.query } }),
    )
    input?.focus()
  }
}

/** Leave the active scope (Backspace on empty input, pill click, or API). */
export function exitScope(target) {
  const inst = target.root ? target : getInstance(target)
  if (!inst || !inst.scope) return
  inst.scope = null
  syncSearchMeta(inst)
  renderPill(inst)
  inst.root.removeAttribute('data-cmdk-active-scope')
  filterItems(inst)
  sortItems(inst)
  selectFirstItem(inst)
  inst.root.dispatchEvent(new CustomEvent('cmdk-scope-change', { bubbles: true, detail: { scope: null, query: inst.query } }))
  inst.root.dispatchEvent(
    new CustomEvent(SEARCH_CHANGE_EVENT, { bubbles: true, detail: { search: inst.search, scope: null, query: inst.query } }),
  )
}

function config(root) {
  return {
    shouldFilter: root.getAttribute('data-cmdk-should-filter') !== 'false',
    loop: root.hasAttribute('data-cmdk-loop'),
    vimBindings: root.getAttribute('data-cmdk-vim-bindings') !== 'false',
    disablePointerSelection: root.hasAttribute('data-cmdk-disable-pointer-selection'),
    nativeHomeEnd: root.hasAttribute('data-cmdk-native-home-end'),
  }
}

function resolveRoot(target) {
  const el = typeof target === 'string' ? document.querySelector(target) : target
  if (!el) return null
  return el.matches?.(ROOT_SELECTOR) ? el : el.querySelector(ROOT_SELECTOR)
}

export function getInstance(target) {
  const root = resolveRoot(target)
  if (!root) return null
  let inst = instances.get(root)
  if (!inst) inst = createInstance(root)
  return inst
}

function createInstance(root) {
  const inst = {
    root,
    search: '',
    scope: null, // pinned scope (rendered as a pill before the input)
    picker: false, // true while the search starts with the scope-picker prefix
    query: '', // the effective query (picker prefix stripped in picker mode)
    value: (root.getAttribute('data-cmdk-default-value') || '').trim(),
    count: 0,
    filter: null, // per-root custom filter, see setFilter()
    scores: new Map(), // item element → score
    knownItems: new Set(),
    order: new Map(), // element → original index, to restore server order when search clears
    orderUid: 0,
    itemUid: 0,
    highlighted: new Set(), // [cmdk-item-label] elements currently holding <mark cmdk-match>
    disconnect: [], // teardown callbacks, run by destroy()
  }
  instances.set(root, inst)

  wireIds(inst)
  registerNodes(inst)
  adoptHighlights(inst)
  // A server-rendered input value is the initial search (React: <Command.Input value>).
  inst.search = root.querySelector(INPUT_SELECTOR)?.value || ''
  // Server-rendered scope state: data-cmdk-active-scope pins the pill at init.
  const ssrScope = root.getAttribute('data-cmdk-active-scope')
  if (ssrScope) {
    inst.scope = ssrScope
    renderPill(inst)
  }
  syncSearchMeta(inst)
  filterItems(inst)
  sortItems(inst)
  if (!inst.value || !getSelectedItem(inst)) selectFirstItem(inst, { scroll: false, emit: false })
  else applySelection(inst)
  observeListHeight(inst)

  // Item mount/unmount lifecycle (Turbo streams, morphing, manual DOM changes).
  const observer = new MutationObserver(() => onItemsChanged(inst))
  observer.observe(root, { childList: true, subtree: true })
  inst.disconnect.push(() => observer.disconnect())

  return inst
}

function wireIds(inst) {
  const { root } = inst
  if (!root.id) root.id = `cmdk-${++uid}`
  const label = root.querySelector('[cmdk-label]')
  const input = root.querySelector(INPUT_SELECTOR)
  const list = root.querySelector(LIST_SELECTOR)
  if (label && !label.id) label.id = `${root.id}-label`
  if (input) {
    if (!input.id) input.id = `${root.id}-input`
    if (label) {
      label.htmlFor = input.id
      input.setAttribute('aria-labelledby', label.id)
    }
  }
  if (list) {
    if (!list.id) list.id = `${root.id}-list`
    if (input) input.setAttribute('aria-controls', list.id)
  }
}

/** Assign ids, infer data-value from textContent (like React cmdk), record DOM order. */
function registerNodes(inst) {
  const { root } = inst
  for (const item of root.querySelectorAll(ITEM_SELECTOR)) {
    if (!item.id) item.id = `${root.id}-item-${++inst.itemUid}`
    if (!item.hasAttribute(VALUE_ATTR)) item.setAttribute(VALUE_ATTR, (item.textContent || '').trim())
    inst.knownItems.add(item)
  }
  for (const group of root.querySelectorAll(GROUP_SELECTOR)) {
    if (!group.hasAttribute(VALUE_ATTR)) {
      const heading = group.querySelector(GROUP_HEADING_SELECTOR)
      group.setAttribute(VALUE_ATTR, (heading?.textContent || '').trim())
    }
  }
  for (const container of containersOf(inst)) {
    for (const child of container.children) {
      if (!inst.order.has(child)) inst.order.set(child, inst.orderUid++)
    }
  }
}

function containersOf(inst) {
  const sizer = inst.root.querySelector(SIZER_SELECTOR)
  return [...(sizer ? [sizer] : []), ...inst.root.querySelectorAll(GROUP_ITEMS_SELECTOR)]
}

function itemValue(item) {
  return item.getAttribute(VALUE_ATTR) || ''
}

function itemKeywords(item) {
  return (item.getAttribute('data-cmdk-keywords') || '').split(' ').filter(Boolean)
}

/** forceMount items are always rendered and excluded from filtering, like in React. */
function forceMounted(item) {
  return (
    item.hasAttribute('data-cmdk-force-mount') ||
    Boolean(item.closest(GROUP_SELECTOR)?.hasAttribute('data-cmdk-force-mount'))
  )
}

function isVisible(el) {
  if (el.style.display === 'none') return false
  const group = el.closest(GROUP_SELECTOR)
  if (group && group.hidden) return false
  return true
}

function getValidItems(inst) {
  return Array.from(inst.root.querySelectorAll(VALID_ITEM_SELECTOR)).filter(isVisible)
}

function getSelectedItem(inst) {
  if (!inst.value) return null
  return Array.from(inst.root.querySelectorAll(ITEM_SELECTOR)).find((item) => itemValue(item) === inst.value) || null
}

function score(inst, value, keywords, item) {
  const filter = inst.filter || globalFilter
  // The query (scope trigger stripped) is what gets matched; the item element
  // is an extension over the React filter signature for userland scoping.
  return value ? filter(value, inst.query, keywords, item) : 0
}

/** Set an inline display only when it changes (unchanged writes still cost style work). */
function setDisplay(el, shown) {
  const display = shown ? '' : 'none'
  if (el.style.display !== display) el.style.display = display
}

/** Port of filterItems(): score items, toggle item/group/separator/empty visibility. */
function filterItems(inst) {
  const { root, search, scope, picker } = inst
  const filtering = Boolean(search) && config(root).shouldFilter
  // Match highlighting is opt-in markup; skip all of it when no item uses it.
  const highlight = inst.highlighted.size > 0 || root.querySelector(ITEM_LABEL_SELECTOR) !== null
  let count = 0

  // Skip per-item ancestor lookups for features the menu doesn't use.
  const anyForceMount = root.querySelector('[data-cmdk-force-mount]') !== null
  const anyScopeOnly = root.querySelector('[data-cmdk-scope-only]') !== null
  const anyServerFiltered = root.querySelector('[data-cmdk-server-filtered]') !== null

  for (const item of root.querySelectorAll(ITEM_SELECTOR)) {
    const fm = anyForceMount && forceMounted(item)
    // Scope-only items require deliberate entry: hidden (even from global
    // search and force mount) unless their scope is the active one.
    const scopeHidden = anyScopeOnly && isScopeOnly(item) && itemScope(item) !== scope
    let rank
    let scored = false // matched against the query (so its label can be highlighted)
    if (scopeHidden) {
      rank = 0
    } else if (picker) {
      // Scope-picker mode ("/..."): only scope-entry items are suggested.
      scored = item.hasAttribute('data-cmdk-enters-scope')
      rank = scored ? score(inst, itemValue(item), itemKeywords(item), item) : 0
    } else if (scope && itemScope(item) !== scope) {
      rank = 0
    } else if (anyServerFiltered && item.closest('[data-cmdk-server-filtered]')) {
      // The server already filtered these (e.g. a Turbo-framed scope search);
      // don't fuzzy-match them against the query again.
      rank = 1
    } else {
      scored = filtering
      rank = filtering ? score(inst, itemValue(item), itemKeywords(item), item) : 1
    }
    inst.scores.set(item, rank)
    const shown = !scopeHidden && (fm || rank > 0)
    // React removes filtered items from the DOM; we hide them with an inline
    // style so theme CSS (e.g. `[cmdk-item] { display: flex }`) cannot win.
    setDisplay(item, shown)
    if (!fm && shown) count++
    if (highlight) highlightItem(inst, item, shown && scored && (filtering || picker) ? inst.query : '')
  }
  inst.count = count

  for (const group of root.querySelectorAll(GROUP_SELECTOR)) {
    let shown = !(isScopeOnly(group) && itemScope(group) !== scope)
    if (shown && (filtering || picker || scope)) {
      shown =
        (!picker && group.hasAttribute('data-cmdk-force-mount')) ||
        Array.from(group.querySelectorAll(ITEM_SELECTOR)).some(
          (item) => !(anyForceMount && forceMounted(item)) && inst.scores.get(item) > 0,
        )
    } else if (shown) {
      // Hide groups whose items are all scope-hidden; keep itemless groups
      // visible (they may be filled by a server-backed scope search).
      const items = Array.from(group.querySelectorAll(ITEM_SELECTOR))
      shown = items.length === 0 || items.some((item) => item.style.display !== 'none')
    }
    if (group.hidden !== !shown) group.hidden = !shown
  }

  for (const separator of root.querySelectorAll('[cmdk-separator]')) {
    const shown = (!search && !scope) || separator.hasAttribute('data-cmdk-always-render')
    setDisplay(separator, shown)
  }

  for (const empty of root.querySelectorAll('[cmdk-empty]')) {
    // Server-rendered with the `hidden` attribute (no inline style, so a
    // strict CSP allows it); from here on the inline display decides, as
    // before, so theme CSS cannot show it while there are results.
    if (empty.hidden !== (count !== 0)) empty.hidden = count !== 0
    setDisplay(empty, count === 0)
  }
}

// ── Match highlighting ([cmdk-item-label] → <mark cmdk-match>) ──

const labelMarks = new WeakMap() // label element → the matches currently rendered ("1,2,5")

/** Highlight `query`'s matches in the item's [cmdk-item-label]s ('' restores the text). */
function highlightItem(inst, item, query) {
  const labels = item.querySelectorAll(ITEM_LABEL_SELECTOR)
  for (const label of labels) {
    const marked = inst.highlighted.has(label)
    if (!query && !marked) continue
    // Marks only wrap runs of the label's text, so its textContent is always
    // the plain text, highlighted or not.
    const text = label.textContent
    const matches = query ? commandScoreWithMatches(text, query).matches : []
    const key = matches.join(',')
    // Unchanged since the last pass (and not re-rendered by a morph meanwhile).
    if (marked && labelMarks.get(label) === key && label.childElementCount > 0) continue
    if (!matches.length) {
      if (marked) label.textContent = text
      inst.highlighted.delete(label)
      labelMarks.delete(label)
      continue
    }
    renderMarks(label, text, matches)
    inst.highlighted.add(label)
    labelMarks.set(label, key)
  }
}

/** Rebuild a label as text nodes and <mark cmdk-match> runs (never innerHTML). */
function renderMarks(label, text, matches) {
  const fragment = document.createDocumentFragment()
  let position = 0
  for (let i = 0; i < matches.length; ) {
    let end = i
    while (end + 1 < matches.length && matches[end + 1] === matches[end] + 1) end++
    const from = matches[i]
    const to = matches[end] + 1
    if (from > position) fragment.appendChild(document.createTextNode(text.slice(position, from)))
    const mark = document.createElement('mark')
    mark.setAttribute(MATCH_ATTR, '')
    mark.textContent = text.slice(from, to)
    fragment.appendChild(mark)
    position = to
    i = end + 1
  }
  if (position < text.length) fragment.appendChild(document.createTextNode(text.slice(position)))
  label.replaceChildren(fragment)
}

/** Labels that already hold marks (a page restored from Turbo's cache, a re-init after destroy). */
function adoptHighlights(inst) {
  for (const mark of inst.root.querySelectorAll(`${ITEM_LABEL_SELECTOR} mark[${MATCH_ATTR}]`)) {
    inst.highlighted.add(mark.closest(ITEM_LABEL_SELECTOR))
  }
}

/** Find the ancestor of `el` that is a direct child of `container`. */
function directChild(container, el) {
  let node = el
  while (node && node.parentElement !== container) node = node.parentElement
  return node || el
}

/** Port of sort(): order items by score and groups by their best item. */
function sortItems(inst) {
  const { root, search, scores } = inst
  const sizer = root.querySelector(SIZER_SELECTOR) || root.querySelector(LIST_SELECTOR) || root

  if (!search || !config(root).shouldFilter) {
    // Deviation from React cmdk: restore the server-rendered order once the
    // search clears, since that order is canonical.
    restoreOrder(inst)
    return
  }

  // The result is what appending every visible item (in score order) and then
  // every visible group (by best item) to the end of its container produces;
  // planned per container first, so nodes already in place are not moved.
  const plan = new Map() // container → Map(child → sequence; the last append wins)
  let seq = 0
  let direct = true
  const append = (container, child) => {
    if (child.parentElement !== container) direct = false
    let moves = plan.get(container)
    if (!moves) plan.set(container, (moves = new Map()))
    moves.delete(child)
    moves.set(child, seq++)
  }

  const items = getValidItems(inst).sort((a, b) => (scores.get(b) ?? 0) - (scores.get(a) ?? 0))
  for (const item of items) {
    const container = item.closest(GROUP_ITEMS_SELECTOR) || sizer
    append(container, directChild(container, item))
  }

  const groups = Array.from(root.querySelectorAll(GROUP_SELECTOR))
    .filter((group) => !group.hidden)
    .map((group) => {
      let max = 0
      for (const item of group.querySelectorAll(ITEM_SELECTOR)) {
        max = Math.max(max, scores.get(item) ?? 0)
      }
      return [group, max]
    })
    .sort((a, b) => b[1] - a[1])
  for (const [group] of groups) {
    if (group.parentElement) append(group.parentElement, group)
  }

  if (!direct) {
    // Unusual markup (an item outside its container): replay the appends.
    for (const [container, moves] of plan) for (const child of moves.keys()) container.appendChild(child)
    return
  }
  for (const [container, moves] of plan) {
    const stay = Array.from(container.children).filter((child) => !moves.has(child))
    reorder(container, stay.concat(Array.from(moves.keys())))
  }
}

/** Make `container`'s element children follow `desired`, moving only misplaced nodes. */
function reorder(container, desired) {
  let current = container.firstElementChild
  for (const el of desired) {
    if (current === el) {
      current = current.nextElementSibling
      continue
    }
    container.insertBefore(el, current)
  }
}

function restoreOrder(inst) {
  for (const container of containersOf(inst)) {
    const children = Array.from(container.children)
    const known = children
      .filter((child) => inst.order.has(child))
      .sort((a, b) => inst.order.get(a) - inst.order.get(b))
    reorder(container, children.filter((child) => !inst.order.has(child)).concat(known))
  }
}

function applySelection(inst) {
  let selected = null
  for (const item of inst.root.querySelectorAll(ITEM_SELECTOR)) {
    const isSelected = Boolean(inst.value) && itemValue(item) === inst.value
    if (isSelected && !selected) selected = item
    const state = String(isSelected)
    if (item.getAttribute('aria-selected') !== state) item.setAttribute('aria-selected', state)
    if (item.getAttribute('data-selected') !== state) item.setAttribute('data-selected', state)
  }

  for (const el of [inst.root.querySelector(INPUT_SELECTOR), inst.root.querySelector(LIST_SELECTOR)]) {
    if (!el) continue
    if (selected) {
      if (el.getAttribute('aria-activedescendant') !== selected.id) el.setAttribute('aria-activedescendant', selected.id)
    } else el.removeAttribute('aria-activedescendant')
  }

  updateFooterHint(inst, selected)
}

/** Fill [cmdk-footer-hint] with the selected item's data-cmdk-hint / data-cmdk-kbd. */
function updateFooterHint(inst, selected) {
  const el = inst.root.querySelector('[cmdk-footer-hint]')
  if (!el) return
  const hint = selected?.getAttribute('data-cmdk-hint')
  const kbd = selected?.getAttribute('data-cmdk-kbd')
  el.replaceChildren()
  el.toggleAttribute('data-empty', !hint && !kbd)
  if (hint) {
    const label = document.createElement('span')
    label.textContent = hint
    el.appendChild(label)
  }
  for (const key of (kbd || '').split(/\s+/).filter(Boolean)) {
    const cap = document.createElement('kbd')
    cap.textContent = key
    el.appendChild(cap)
  }
}

function scrollSelectedIntoView(inst) {
  const item = getSelectedItem(inst)
  if (!item) return

  const siblings = item.parentElement ? Array.from(item.parentElement.children) : []
  if (siblings.find(isVisible) === item) {
    // First item in its group: keep the heading in view too.
    item.closest(GROUP_SELECTOR)?.querySelector(GROUP_HEADING_SELECTOR)?.scrollIntoView({ block: 'nearest' })
  }
  item.scrollIntoView({ block: 'nearest' })
}

function setValueState(inst, value, { scroll = true, emit = true } = {}) {
  value = value || ''
  if (Object.is(inst.value, value)) return
  inst.value = value
  applySelection(inst)
  if (scroll) scrollSelectedIntoView(inst)
  if (emit) inst.root.dispatchEvent(new CustomEvent(VALUE_CHANGE_EVENT, { bubbles: true, detail: { value } }))
}

function setSearchState(inst, search) {
  if (Object.is(inst.search, search)) return
  inst.search = search

  if (!inst.scope) {
    // Typing a scope name out in picker mode ("/user ") commits it.
    const pc = pickerChar(inst.root)
    if (pc && search.startsWith(pc)) {
      const rest = search.slice(pc.length)
      const hit = scopesOf(inst.root).find((name) => rest === `${name} `)
      if (hit) return enterScope(inst, hit)
    }
  }

  syncSearchMeta(inst)
  filterItems(inst)
  sortItems(inst)
  selectFirstItem(inst)
  inst.root.dispatchEvent(
    new CustomEvent(SEARCH_CHANGE_EVENT, { bubbles: true, detail: { search, scope: inst.scope, query: inst.query } }),
  )
}

function selectFirstItem(inst, opts) {
  const item = getValidItems(inst)[0]
  setValueState(inst, item ? itemValue(item) : '', opts)
}

/** Item chosen via click or Enter. Dispatches cmdk-item-select; honors data-href. */
function triggerSelect(inst, item, source) {
  if (item.getAttribute('aria-disabled') === 'true') return
  const value = itemValue(item)
  setValueState(inst, value, { scroll: false })
  // The modifier keys held during the click or Enter, so listeners can offer
  // an alternate action (e.g. ⌘/Ctrl+Enter opens a "create" URL instead).
  const detail = {
    value,
    metaKey: Boolean(source?.metaKey),
    ctrlKey: Boolean(source?.ctrlKey),
    shiftKey: Boolean(source?.shiftKey),
    altKey: Boolean(source?.altKey),
  }
  const event = new CustomEvent(SELECT_EVENT, { bubbles: true, cancelable: true, detail })
  const proceed = item.dispatchEvent(event)
  if (!proceed) return
  const enters = item.getAttribute('data-cmdk-enters-scope')
  if (enters) {
    enterScope(inst, enters)
    return
  }
  const href = item.getAttribute('data-href')
  if (href) {
    if (window.Turbo?.visit) window.Turbo.visit(href)
    else window.location.assign(href)
  }
}

// ── Keyboard navigation ──

function updateSelectedToIndex(inst, index) {
  const item = getValidItems(inst)[index]
  if (item) setValueState(inst, itemValue(item))
}

function updateSelectedByItem(inst, change) {
  const selected = getSelectedItem(inst)
  const items = getValidItems(inst)
  const index = items.findIndex((item) => item === selected)
  let newSelected = items[index + change]

  if (config(inst.root).loop) {
    newSelected =
      index + change < 0 ? items[items.length - 1] : index + change === items.length ? items[0] : items[index + change]
  }

  if (newSelected) setValueState(inst, itemValue(newSelected))
}

function findSibling(el, selector, direction) {
  let sibling = direction > 0 ? el.nextElementSibling : el.previousElementSibling
  while (sibling) {
    if (sibling.matches(selector)) return sibling
    sibling = direction > 0 ? sibling.nextElementSibling : sibling.previousElementSibling
  }
  return null
}

function updateSelectedByGroup(inst, change) {
  const selected = getSelectedItem(inst)
  let group = selected?.closest(GROUP_SELECTOR)
  let item = null

  while (group && !item) {
    group = findSibling(group, GROUP_SELECTOR, change)
    item = group ? Array.from(group.querySelectorAll(VALID_ITEM_SELECTOR)).find(isVisible) : null
  }

  if (item) setValueState(inst, itemValue(item))
  else updateSelectedByItem(inst, change)
}

function next(inst, e) {
  e.preventDefault()
  if (e.metaKey) updateSelectedToIndex(inst, getValidItems(inst).length - 1)
  else if (e.altKey) updateSelectedByGroup(inst, 1)
  else updateSelectedByItem(inst, 1)
}

function prev(inst, e) {
  e.preventDefault()
  if (e.metaKey) updateSelectedToIndex(inst, 0)
  else if (e.altKey) updateSelectedByGroup(inst, -1)
  else updateSelectedByItem(inst, -1)
}

// ── Item lifecycle (MutationObserver callback) ──

function onItemsChanged(inst) {
  const current = new Set(inst.root.querySelectorAll(ITEM_SELECTOR))
  let changed = current.size !== inst.knownItems.size
  if (!changed) {
    for (const item of current) {
      if (!inst.knownItems.has(item)) {
        changed = true
        break
      }
    }
  }
  // Pure reorders (our own sorting) and attribute changes don't re-filter.
  if (!changed) return

  inst.knownItems = current
  registerNodes(inst)
  filterItems(inst)
  sortItems(inst)
  if (!inst.value || !getSelectedItem(inst)) selectFirstItem(inst)
  else applySelection(inst)
}

// ── --cmdk-list-height (port of the List ResizeObserver) ──

function observeListHeight(inst) {
  const list = inst.root.querySelector(LIST_SELECTOR)
  const sizer = inst.root.querySelector(SIZER_SELECTOR)
  if (!list || !sizer || typeof ResizeObserver === 'undefined') return
  const update = () => list.style.setProperty('--cmdk-list-height', sizer.offsetHeight.toFixed(1) + 'px')
  update()
  let frame
  const observer = new ResizeObserver(() => {
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(update)
  })
  observer.observe(sizer)
  inst.disconnect.push(() => {
    observer.disconnect()
    cancelAnimationFrame(frame)
  })
}

// ── Dialog (native <dialog> port of Command.Dialog) ──

function resolveDialog(target) {
  const el = typeof target === 'string' ? document.querySelector(target) : target
  if (!el) return null
  return el.matches?.(DIALOG_SELECTOR) ? el : el.closest?.(DIALOG_SELECTOR) || el.querySelector?.(DIALOG_SELECTOR)
}

export function openDialog(target) {
  const dialog = resolveDialog(target)
  if (!dialog || dialog.open) return
  dialog.showModal()
  const root = dialog.querySelector(ROOT_SELECTOR)
  if (root) {
    getInstance(root)
    root.querySelector(INPUT_SELECTOR)?.focus()
  }
}

export function closeDialog(target) {
  resolveDialog(target)?.close()
}

function setupDialog(dialog) {
  if (knownDialogs.has(dialog)) return
  knownDialogs.add(dialog)
  if (dialog.hasAttribute('data-cmdk-open')) {
    dialog.removeAttribute('data-cmdk-open')
    openDialog(dialog)
  }
}

/**
 * The physical letter for hotkey matching on non-Latin layouts: there ⌘/Ctrl+K
 * reports e.key "л" (Cyrillic) or "κ" (Greek), so when e.key is a letter but
 * not a Latin one, fall back to e.code ("KeyK" → "k"). Null otherwise, so Latin
 * layouts (QWERTY, Dvorak, AZERTY, …) keep matching by e.key alone.
 */
function physicalLetter(e) {
  const key = e.key || ''
  if (key.length !== 1 || /^[a-z]$/i.test(key) || !/\p{L}/u.test(key)) return null
  const physical = /^Key([A-Z])$/.exec(e.code || '')
  return physical ? physical[1].toLowerCase() : null
}

function handleDialogHotkey(e) {
  if (!(e.metaKey || e.ctrlKey) || e.repeat) return
  const key = (e.key || '').toLowerCase()
  const physical = physicalLetter(e)
  // ctrl+n/j/p/k inside a menu with vim bindings is navigation, not a hotkey.
  if (e.ctrlKey && !e.metaKey && ['n', 'j', 'p', 'k'].some((k) => k === key || k === physical)) {
    const root = e.target instanceof Element ? e.target.closest(ROOT_SELECTOR) : null
    if (root && config(root).vimBindings) return
  }
  for (const dialog of document.querySelectorAll(`${DIALOG_SELECTOR}[data-cmdk-dialog-hotkey]`)) {
    const hotkey = dialog.getAttribute('data-cmdk-dialog-hotkey').toLowerCase()
    if (key === hotkey || physical === hotkey) {
      e.preventDefault()
      dialog.open ? closeDialog(dialog) : openDialog(dialog)
    }
  }
}

// ── Delegated events ──

function onKeydown(e) {
  handleDialogHotkey(e)

  const root = e.target instanceof Element ? e.target.closest(ROOT_SELECTOR) : null
  if (!root) return
  const inst = getInstance(root)

  // IME composition guard (keyCode 229 covers legacy CJK IMEs).
  if (e.defaultPrevented || e.isComposing || e.keyCode === 229) return
  const { vimBindings, nativeHomeEnd } = config(root)

  switch (e.key) {
    case 'n':
    case 'j': {
      if (vimBindings && e.ctrlKey) next(inst, e)
      break
    }
    case 'ArrowDown': {
      next(inst, e)
      break
    }
    case 'p':
    case 'k': {
      if (vimBindings && e.ctrlKey) prev(inst, e)
      break
    }
    case 'ArrowUp': {
      prev(inst, e)
      break
    }
    case 'Backspace': {
      // Backspace on an empty input pops the scope pill.
      if (inst.scope && e.target.matches?.(INPUT_SELECTOR) && e.target.value === '') {
        e.preventDefault()
        exitScope(inst)
      }
      break
    }
    case 'Home': {
      // data-cmdk-native-home-end: Home/End move the caret inside the input.
      if (nativeHomeEnd && e.target.matches?.(INPUT_SELECTOR)) break
      e.preventDefault()
      updateSelectedToIndex(inst, 0)
      break
    }
    case 'End': {
      if (nativeHomeEnd && e.target.matches?.(INPUT_SELECTOR)) break
      e.preventDefault()
      updateSelectedToIndex(inst, getValidItems(inst).length - 1)
      break
    }
    case 'Enter': {
      e.preventDefault()
      const item = getSelectedItem(inst)
      if (item) triggerSelect(inst, item, e)
      break
    }
  }
}

function onInput(e) {
  if (!(e.target instanceof Element) || !e.target.matches(INPUT_SELECTOR)) return
  const root = e.target.closest(ROOT_SELECTOR)
  if (root) setSearchState(getInstance(root), e.target.value)
}

function onClick(e) {
  if (!(e.target instanceof Element)) return

  // Click on the backdrop closes the dialog (the dialog itself is the target).
  if (e.target instanceof HTMLDialogElement && e.target.matches(DIALOG_SELECTOR)) {
    const rect = e.target.getBoundingClientRect()
    const inside =
      e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom
    if (!inside) closeDialog(e.target)
    return
  }

  const pill = e.target.closest('[cmdk-scope-pill]')
  if (pill) {
    const root = pill.closest(ROOT_SELECTOR)
    if (root) exitScope(getInstance(root))
    return
  }

  const item = e.target.closest(ITEM_SELECTOR)
  const root = item?.closest(ROOT_SELECTOR)
  if (item && root) triggerSelect(getInstance(root), item, e)
}

function onPointerMove(e) {
  if (!(e.target instanceof Element)) return
  // Touch "hover" is just scrolling — don't drag the selection under the finger.
  if (e.pointerType === 'touch') return
  const item = e.target.closest(ITEM_SELECTOR)
  const root = item?.closest(ROOT_SELECTOR)
  if (!item || !root) return
  if (item.getAttribute('aria-disabled') === 'true') return
  const inst = getInstance(root)
  if (config(root).disablePointerSelection) return
  setValueState(inst, itemValue(item), { scroll: false })
}

// ── Public API ──

export function scan(node = document) {
  if (node instanceof Element && node.matches(ROOT_SELECTOR)) getInstance(node)
  if (node instanceof Element && node.matches(DIALOG_SELECTOR)) setupDialog(node)
  node.querySelectorAll?.(ROOT_SELECTOR).forEach((root) => getInstance(root))
  node.querySelectorAll?.(DIALOG_SELECTOR).forEach(setupDialog)
}

/**
 * Tear down a menu's instance: disconnect its MutationObserver and
 * ResizeObserver, cancel pending frames and forget its state. The DOM is left
 * as it is. Call it when a menu leaves the page (e.g. from a Stimulus
 * controller's disconnect()); a later scan() or interaction with the same
 * element initialises it afresh.
 */
export function destroy(target) {
  const root = resolveRoot(target)
  const inst = root && instances.get(root)
  if (!inst) return
  for (const teardown of inst.disconnect.splice(0)) teardown()
  instances.delete(root)
}

/** Programmatically set the search query (the React `<Command.Input value>` controlled mode). */
export function setSearch(target, search) {
  const inst = getInstance(target)
  if (!inst) return
  const input = inst.root.querySelector(INPUT_SELECTOR)
  if (input) input.value = search
  setSearchState(inst, search)
}

/** Programmatically set the selected value (the React `<Command value>` controlled mode). */
export function setValue(target, value) {
  const inst = getInstance(target)
  if (inst) setValueState(inst, (value || '').trim())
}

/** Read the current state, the closest equivalent of React's useCommandState. */
export function getState(target) {
  const inst = getInstance(target)
  if (!inst) return null
  return {
    search: inst.search,
    scope: inst.scope,
    picker: inst.picker,
    query: inst.query,
    value: inst.value,
    filtered: { count: inst.count },
  }
}

/**
 * Override the filter function: `setFilter(fn)` replaces the default for all
 * menus, `setFilter(rootEl, fn)` for one. Pass `null` to reset.
 * fn(value, query, keywords, item) → number in [0, 1], 0 hides the item.
 * The item element (4th arg, an extension over the React signature) enables
 * fully custom search syntax — scoping, operators, per-item logic.
 */
export function setFilter(target, fn) {
  if (typeof target === 'function' || target === null) {
    globalFilter = target || defaultFilter
    return
  }
  const inst = getInstance(target)
  if (!inst) return
  inst.filter = fn
  filterItems(inst)
  sortItems(inst)
  selectFirstItem(inst)
}

/**
 * Sensible default dialog placement: a top-third command palette, centered
 * horizontally. CSS resets (e.g. Tailwind preflight's universal `margin: 0`)
 * destroy the native <dialog> centering, so the runtime re-asserts it here.
 * `:where()` keeps specificity at zero — any consumer rule on
 * `dialog[cmdk-dialog]` or a class overrides these.
 *
 * Identical to assets/css/cmdk_base.css (a test keeps the two in sync).
 */
const BASE_STYLES = `
:where(dialog[cmdk-dialog]) {
  position: fixed;
  inset: 0;
  margin: 16dvh auto auto;
  width: fit-content;
  height: fit-content;
  max-width: calc(100vw - 2rem);
  max-height: calc(84dvh - 2rem);
  /* The list scrolls internally; keep the dialog itself unclipped so a themed
     root's border-radius and drop-shadow are not squared off at the corners. */
  overflow: visible;
}
:where(dialog[cmdk-dialog])::backdrop {
  background: transparent;
}
:where([cmdk-list-sizer]) {
  display: flow-root; /* child margins must count into --cmdk-list-height */
}
/* Server-rendered hidden parts stay hidden even when theme CSS sets display. */
[cmdk-label][hidden],
[cmdk-empty][hidden] {
  display: none !important;
}
@media (max-width: 640px) {
  :where(dialog[cmdk-dialog]) {
    margin: 0.5rem auto auto;
    width: calc(100vw - 1rem);
    max-width: calc(100vw - 1rem);
    max-height: calc(100dvh - 1rem);
  }
}
`

/**
 * Inject BASE_STYLES once, as a <style id="cmdk-base-styles"> in <head>.
 * `<meta name="cmdk-base-styles" content="…">` controls it:
 *   off (or false/none) — inject nothing; include cmdk_base.css yourself
 *   layer               — wrap the rules in `@layer cmdk`
 *   layer:<name>        — wrap them in `@layer <name>`
 * The <style> gets the nonce from `<meta name="csp-nonce">` (Rails'
 * csp_meta_tag) when present, so a nonce-based style-src CSP accepts it.
 */
function injectBaseStyles() {
  if (document.getElementById('cmdk-base-styles')) return
  const setting = (document.querySelector('meta[name="cmdk-base-styles"]')?.getAttribute('content') || '').trim()
  if (/^(off|false|none)$/i.test(setting)) return
  const layer = /^layer(?::\s*([\w-]+))?$/i.exec(setting)
  const style = document.createElement('style')
  style.id = 'cmdk-base-styles'
  const nonce = document.querySelector('meta[name="csp-nonce"]')?.getAttribute('content')
  if (nonce) style.nonce = nonce
  style.textContent = layer ? `@layer ${layer[1] || 'cmdk'} {${BASE_STYLES}}\n` : BASE_STYLES
  document.head.appendChild(style)
}

/**
 * Turbo snapshots the page before leaving it; an open modal would come back
 * from the cache as a non-modal `<dialog open>`. Close cmdk dialogs first.
 */
function onBeforeCache() {
  for (const dialog of document.querySelectorAll(`${DIALOG_SELECTOR}[open]`)) dialog.close()
}

let started = false

export function start() {
  if (started || typeof document === 'undefined') return
  started = true
  injectBaseStyles()

  document.addEventListener('keydown', onKeydown)
  document.addEventListener('input', onInput)
  document.addEventListener('click', onClick)
  document.addEventListener('pointermove', onPointerMove)
  document.addEventListener('turbo:before-cache', onBeforeCache)

  const init = () => scan()
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init)
  else init()

  // Picks up roots/dialogs added by Turbo navigation, frames and streams.
  new MutationObserver((records) => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        // Highlight marks are the runtime's own nodes, never roots or dialogs.
        if (node.nodeType === Node.ELEMENT_NODE && !node.hasAttribute(MATCH_ATTR)) scan(node)
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true })
}

const Cmdk = {
  start,
  scan,
  destroy,
  commandScore,
  commandScoreWithMatches,
  defaultFilter,
  setFilter,
  setSearch,
  setValue,
  getState,
  getInstance,
  enterScope,
  exitScope,
  openDialog,
  closeDialog,
}

if (typeof window !== 'undefined') window.Cmdk = Cmdk

start()

export default Cmdk
