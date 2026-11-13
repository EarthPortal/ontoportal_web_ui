import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="recommended-badges" (the Edit form of a submission, submissions/edit.html.haml)
//
// Live "Recommended" badges of the Edit tabs: the badge of a Recommended field is shown only while the field is empty,
// and the count next to each tab is the number of its badges shown. The badges and counts are rendered from the saved
// values by SubmissionInputsHelper#recommended_badge and #recommended_count_badge; this controller updates them while
// the author types, chooses or removes a value.
//
// Display only: it reads the values of the fields, it never changes them, and nothing of it is sent with the form.
// Only the Recommended fields are concerned (the fields with a [data-recommended-badge]).
// Nothing changes when the page opens: a field is checked again only after the author used it.
export default class extends Controller {
  connect () {
    this.usedFields = new WeakSet()
    this.markUsed = this.#markUsed.bind(this)
    this.valueChanged = this.#valueChanged.bind(this)

    // capture phase: the field is marked before its own actions run (e.g. the delete button removes its list row)
    this.element.addEventListener('click', this.markUsed, true)
    this.element.addEventListener('keydown', this.markUsed, true)
    // typing, a choice in a select, a date chosen in the calendar
    this.element.addEventListener('input', this.valueChanged)
    this.element.addEventListener('change', this.valueChanged)
    // a list row added or removed, an agent chosen or removed (turbo frame content replaced)
    this.observer = new MutationObserver(this.#contentChanged.bind(this))
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect () {
    this.element.removeEventListener('click', this.markUsed, true)
    this.element.removeEventListener('keydown', this.markUsed, true)
    this.element.removeEventListener('input', this.valueChanged)
    this.element.removeEventListener('change', this.valueChanged)
    this.observer.disconnect()
  }

  #markUsed (event) {
    const field = this.#recommendedField(event.target)
    if (field) this.usedFields.add(field)
  }

  #valueChanged (event) {
    const field = this.#recommendedField(event.target)
    if (!field) return

    this.usedFields.add(field)
    this.#refresh(field)
  }

  #contentChanged (mutations) {
    const fields = new Set()
    mutations.forEach((mutation) => {
      const field = this.#recommendedField(mutation.target)
      if (field && this.usedFields.has(field)) fields.add(field)
    })
    fields.forEach((field) => this.#refresh(field))
  }

  // The block of one attribute (SubmissionsHelper#attribute_form_group_container), only if it has a Recommended badge
  #recommendedField (node) {
    const element = node instanceof Element ? node : node?.parentElement
    const field = element?.closest('[id$="_from_group_input"]')
    return field && this.#badge(field) ? field : null
  }

  #badge (field) {
    return field.querySelector('[data-recommended-badge]')
  }

  #refresh (field) {
    const badge = this.#badge(field)
    const empty = !this.#filled(field, badge.dataset.recommendedBadge, badge.dataset.recommendedAgent === 'true')
    const shown = !badge.classList.contains('d-none')
    if (empty === shown) return

    badge.classList.toggle('d-none', !empty)
    this.#changeTabCount(badge, empty ? 1 : -1)
  }

  // Same idea as SubmissionInputsHelper#metadata_value_blank?, read from the inputs sent with the form
  // (name submission[attribute]...): a text, a chosen option, a list row not empty.
  // An agent field is filled only when an agent is chosen (hidden input submission[attribute][row][id]),
  // not while a name is searched or a new agent is being created.
  #filled (field, attribute, agent) {
    const prefix = `submission[${attribute}]`
    return Array.from(field.querySelectorAll('input, select, textarea')).some((input) => {
      const name = input.name || ''
      if (!name.startsWith(prefix) || input.disabled) return false
      if (agent) return /^\[[^\]]*\]\[id\]$/.test(name.slice(prefix.length)) && input.value.trim() !== ''
      if (input.type === 'checkbox' || input.type === 'radio') return input.checked
      if (input instanceof HTMLSelectElement) return Array.from(input.selectedOptions).some((option) => option.value.trim() !== '')
      return input.value.trim() !== ''
    })
  }

  // The count of the tab where the badge is (left column of the Edit page); hidden at 0.
  // No count when it is not there (count unknown, or fields selected with the search instead of the tabs).
  #changeTabCount (badge, delta) {
    const tab = badge.closest('.tab-pane')
    if (!tab || !tab.id) return

    const count = this.element.querySelector(`a[href="#${tab.id}"] [data-recommended-count]`)
    if (!count) return

    const value = Math.max(0, (parseInt(count.textContent, 10) || 0) + delta)
    count.textContent = value
    count.classList.toggle('d-none', value === 0)
  }
}
