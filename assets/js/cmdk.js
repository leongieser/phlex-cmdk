/**
 * cmdk runtime — a dependency-free port of cmdk (React) for server-rendered HTML.
 *
 * Pairs with the `cmdk-phlex` Ruby gem, which renders the same markup contract
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
 *   cmdk-item-select   detail: { value }  — item chosen via click or Enter (cancelable)
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

function commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, stringIndex, abbreviationIndex, memoizedResults) {
  if (abbreviationIndex === abbreviation.length) {
    if (stringIndex === string.length) {
      return SCORE_CONTINUE_MATCH
    }
    return PENALTY_NOT_COMPLETE
  }

  const memoizeKey = `${stringIndex},${abbreviationIndex}`
  if (memoizedResults[memoizeKey] !== undefined) {
    return memoizedResults[memoizeKey]
  }

  const abbreviationChar = lowerAbbreviation.charAt(abbreviationIndex)
  let index = lowerString.indexOf(abbreviationChar, stringIndex)
  let highScore = 0

  let score, transposedScore, wordBreaks, spaceBreaks

  while (index >= 0) {
    score = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 1, memoizedResults)
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
      transposedScore = commandScoreInner(string, abbreviation, lowerString, lowerAbbreviation, index + 1, abbreviationIndex + 2, memoizedResults)

      if (transposedScore * SCORE_TRANSPOSITION > score) {
        score = transposedScore * SCORE_TRANSPOSITION
      }
    }

    if (score > highScore) {
      highScore = score
    }

    index = lowerString.indexOf(abbreviationChar, index + 1)
  }

  memoizedResults[memoizeKey] = highScore
  return highScore
}

function formatInput(string) {
  return string.toLowerCase().replace(COUNT_SPACE_REGEXP, ' ')
}

export function commandScore(string, abbreviation, aliases) {
  string = aliases && aliases.length > 0 ? `${string + ' ' + aliases.join(' ')}` : string
  return commandScoreInner(string, abbreviation, formatInput(string), formatInput(abbreviation), 0, 0, {})
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
  }
  instances.set(root, inst)

  wireIds(inst)
  registerNodes(inst)
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
  new MutationObserver(() => onItemsChanged(inst)).observe(root, { childList: true, subtree: true })

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

/** Port of filterItems(): score items, toggle item/group/separator/empty visibility. */
function filterItems(inst) {
  const { root, search, scope, picker } = inst
  const filtering = Boolean(search) && config(root).shouldFilter
  let count = 0

  for (const item of root.querySelectorAll(ITEM_SELECTOR)) {
    const fm = forceMounted(item)
    // Scope-only items require deliberate entry: hidden (even from global
    // search and force mount) unless their scope is the active one.
    const scopeHidden = isScopeOnly(item) && itemScope(item) !== scope
    let rank
    if (scopeHidden) {
      rank = 0
    } else if (picker) {
      // Scope-picker mode ("/..."): only scope-entry items are suggested.
      rank = item.hasAttribute('data-cmdk-enters-scope')
        ? score(inst, itemValue(item), itemKeywords(item), item)
        : 0
    } else if (scope && itemScope(item) !== scope) {
      rank = 0
    } else {
      rank = filtering ? score(inst, itemValue(item), itemKeywords(item), item) : 1
    }
    inst.scores.set(item, rank)
    const shown = !scopeHidden && (fm || rank > 0)
    // React removes filtered items from the DOM; we hide them with an inline
    // style so theme CSS (e.g. `[cmdk-item] { display: flex }`) cannot win.
    item.style.display = shown ? '' : 'none'
    if (!fm && shown) count++
  }
  inst.count = count

  for (const group of root.querySelectorAll(GROUP_SELECTOR)) {
    let shown = !(isScopeOnly(group) && itemScope(group) !== scope)
    if (shown && (filtering || picker || scope)) {
      shown =
        (!picker && group.hasAttribute('data-cmdk-force-mount')) ||
        Array.from(group.querySelectorAll(ITEM_SELECTOR)).some(
          (item) => !forceMounted(item) && inst.scores.get(item) > 0,
        )
    } else if (shown) {
      // Hide groups whose items are all scope-hidden; keep itemless groups
      // visible (they may be filled by a server-backed scope search).
      const items = Array.from(group.querySelectorAll(ITEM_SELECTOR))
      shown = items.length === 0 || items.some((item) => item.style.display !== 'none')
    }
    group.hidden = !shown
  }

  for (const separator of root.querySelectorAll('[cmdk-separator]')) {
    const shown = (!search && !scope) || separator.hasAttribute('data-cmdk-always-render')
    separator.style.display = shown ? '' : 'none'
  }

  for (const empty of root.querySelectorAll('[cmdk-empty]')) {
    empty.style.display = count === 0 ? '' : 'none'
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

  getValidItems(inst)
    .sort((a, b) => (scores.get(b) ?? 0) - (scores.get(a) ?? 0))
    .forEach((item) => {
      const container = item.closest(GROUP_ITEMS_SELECTOR) || sizer
      container.appendChild(directChild(container, item))
    })

  Array.from(root.querySelectorAll(GROUP_SELECTOR))
    .filter((group) => !group.hidden)
    .map((group) => {
      let max = 0
      for (const item of group.querySelectorAll(ITEM_SELECTOR)) {
        max = Math.max(max, scores.get(item) ?? 0)
      }
      return [group, max]
    })
    .sort((a, b) => b[1] - a[1])
    .forEach(([group]) => group.parentElement?.appendChild(group))
}

function restoreOrder(inst) {
  for (const container of containersOf(inst)) {
    Array.from(container.children)
      .filter((child) => inst.order.has(child))
      .sort((a, b) => inst.order.get(a) - inst.order.get(b))
      .forEach((child) => container.appendChild(child))
  }
}

function applySelection(inst) {
  let selected = null
  for (const item of inst.root.querySelectorAll(ITEM_SELECTOR)) {
    const isSelected = Boolean(inst.value) && itemValue(item) === inst.value
    if (isSelected && !selected) selected = item
    item.setAttribute('aria-selected', String(isSelected))
    item.setAttribute('data-selected', String(isSelected))
  }

  for (const el of [inst.root.querySelector(INPUT_SELECTOR), inst.root.querySelector(LIST_SELECTOR)]) {
    if (!el) continue
    if (selected) el.setAttribute('aria-activedescendant', selected.id)
    else el.removeAttribute('aria-activedescendant')
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
function triggerSelect(inst, item) {
  if (item.getAttribute('aria-disabled') === 'true') return
  const value = itemValue(item)
  setValueState(inst, value, { scroll: false })
  const event = new CustomEvent(SELECT_EVENT, { bubbles: true, cancelable: true, detail: { value } })
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
  new ResizeObserver(() => {
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(update)
  }).observe(sizer)
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

function handleDialogHotkey(e) {
  if (!(e.metaKey || e.ctrlKey) || e.repeat) return
  for (const dialog of document.querySelectorAll(`${DIALOG_SELECTOR}[data-cmdk-dialog-hotkey]`)) {
    if (e.key.toLowerCase() === dialog.getAttribute('data-cmdk-dialog-hotkey').toLowerCase()) {
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
  const { vimBindings } = config(root)

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
      e.preventDefault()
      updateSelectedToIndex(inst, 0)
      break
    }
    case 'End': {
      e.preventDefault()
      updateSelectedToIndex(inst, getValidItems(inst).length - 1)
      break
    }
    case 'Enter': {
      e.preventDefault()
      const item = getSelectedItem(inst)
      if (item) triggerSelect(inst, item)
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
  if (item && root) triggerSelect(getInstance(root), item)
}

function onPointerMove(e) {
  if (!(e.target instanceof Element)) return
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

let started = false

export function start() {
  if (started || typeof document === 'undefined') return
  started = true

  document.addEventListener('keydown', onKeydown)
  document.addEventListener('input', onInput)
  document.addEventListener('click', onClick)
  document.addEventListener('pointermove', onPointerMove)

  const init = () => scan()
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init)
  else init()

  // Picks up roots/dialogs added by Turbo navigation, frames and streams.
  new MutationObserver((records) => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) scan(node)
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true })
}

const Cmdk = {
  start,
  scan,
  commandScore,
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
