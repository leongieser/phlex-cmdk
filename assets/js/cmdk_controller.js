/**
 * Optional Stimulus base controller for phlex-cmdk. The gem's runtime is
 * framework-free; this thin layer adds idiomatic Hotwire ergonomics on top.
 *
 * Attach to the root (or any ancestor of one):
 *
 *   Cmdk::Root(data: { controller: 'cmdk' }) do ... end
 *
 * Extend it and override the hooks you care about:
 *
 *   import CmdkController from 'phlex-cmdk/controller' // or the copied file
 *
 *   export default class extends CmdkController {
 *     itemSelected({ detail: { value } }) { this.runCommand(value) }
 *     scopeChanged({ detail: { scope, query } }) {
 *       if (scope === 'user') this.frameTarget.src = `/search/users?q=${query}`
 *     }
 *   }
 *
 * Requires `@hotwired/stimulus` (peer) and the runtime resolvable as the bare
 * specifier `cmdk` (importmap: `pin 'cmdk', to: 'cmdk.js'`; bundlers: alias).
 */

import { Controller } from '@hotwired/stimulus'
import Cmdk from 'cmdk'

export default class CmdkController extends Controller {
  #listeners = []

  connect() {
    Cmdk.scan(this.element)
    this.#listeners = [
      ['cmdk-item-select', (event) => this.itemSelected(event)],
      ['cmdk-value-change', (event) => this.valueChanged(event)],
      ['cmdk-search-change', (event) => this.searchChanged(event)],
      ['cmdk-scope-change', (event) => this.scopeChanged(event)],
    ]
    for (const [type, listener] of this.#listeners) this.element.addEventListener(type, listener)
  }

  disconnect() {
    for (const [type, listener] of this.#listeners) this.element.removeEventListener(type, listener)
    this.#listeners = []
  }

  /** The [cmdk-root] this controller manages. */
  get root() {
    return this.element.matches('[cmdk-root]') ? this.element : this.element.querySelector('[cmdk-root]')
  }

  /** Snapshot of { search, scope, picker, query, value, filtered }. */
  get state() {
    return Cmdk.getState(this.root)
  }

  // ── Overridable event hooks (CustomEvents, payload in event.detail) ──

  /** An item was chosen via click or Enter. Cancelable: event.preventDefault(). */
  itemSelected(event) {}

  /** The highlighted item changed. */
  valueChanged(event) {}

  /** The search query changed; detail carries { search, scope, query }. */
  searchChanged(event) {}

  /** A search scope was entered or left. */
  scopeChanged(event) {}

  // ── Actions / imperative API ──

  /** Open the surrounding or contained <dialog cmdk-dialog>. */
  open() {
    Cmdk.openDialog(this.#dialog)
  }

  close() {
    Cmdk.closeDialog(this.#dialog)
  }

  toggle() {
    this.#dialog?.open ? this.close() : this.open()
  }

  setSearch(query) {
    Cmdk.setSearch(this.root, query)
  }

  setValue(value) {
    Cmdk.setValue(this.root, value)
  }

  /**
   * Enter a scope programmatically. Works as a Stimulus action with params:
   *   <button data-action="cmdk#enterScope" data-cmdk-scope-param="user">
   * or called directly: this.enterScope('user')
   */
  enterScope(scopeOrEvent) {
    const scope = typeof scopeOrEvent === 'string' ? scopeOrEvent : scopeOrEvent?.params?.scope
    if (scope) Cmdk.enterScope(this.root, scope)
  }

  exitScope() {
    Cmdk.exitScope(this.root)
  }

  get #dialog() {
    return this.element.closest('dialog[cmdk-dialog]') || this.element.querySelector('dialog[cmdk-dialog]')
  }
}
