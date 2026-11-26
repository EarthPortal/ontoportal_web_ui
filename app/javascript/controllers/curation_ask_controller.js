import { Controller } from "@hotwired/stimulus"

// "Ask the author" window of the Curation tab (admin/curation/ask.html.haml): search among the empty fields,
// shortcuts to tick them, and the Next button, enabled when at least one field is ticked
// Connects to data-controller="curation-ask"
export default class extends Controller {
  static targets = ['search', 'field', 'group', 'next']

  connect() {
    this.update()
  }

  // Hides the fields whose label does not contain the searched text, and the tabs left without field
  search() {
    const text = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ''
    this.fieldTargets.forEach(field => {
      field.classList.toggle('d-none', text !== '' && !field.dataset.label.includes(text))
    })
    this.groupTargets.forEach(group => {
      const shown = group.querySelector('[data-curation-ask-target="field"]:not(.d-none)')
      group.classList.toggle('d-none', !shown)
    })
  }

  selectRecommended(event) {
    event.preventDefault()
    this.#checkboxes().forEach(box => {
      if (box.dataset.recommended === 'true') box.checked = true
    })
    this.update()
  }

  clear(event) {
    event.preventDefault()
    this.#checkboxes().forEach(box => { box.checked = false })
    this.update()
  }

  update() {
    const button = this.hasNextTarget ? this.nextTarget.querySelector('button') : null
    if (!button) return

    const ticked = this.#checkboxes().some(box => box.checked)
    button.disabled = !ticked
    button.classList.toggle('disabled-button', !ticked)
  }

  #checkboxes() {
    return this.fieldTargets.map(field => field.querySelector('input[type="checkbox"]')).filter(Boolean)
  }
}
